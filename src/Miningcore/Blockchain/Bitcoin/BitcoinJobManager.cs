using Autofac;
using Miningcore.Blockchain.Bitcoin.Configuration;
using Miningcore.Blockchain.Bitcoin.DaemonResponses;
using Miningcore.Configuration;
using Miningcore.Contracts;
using Miningcore.Crypto;
using Miningcore.Extensions;
using Miningcore.JsonRpc;
using Miningcore.Messaging;
using Miningcore.Rpc;
using Miningcore.Stratum;
using Miningcore.Time;
using Newtonsoft.Json;
using Newtonsoft.Json.Linq;
using NLog;

namespace Miningcore.Blockchain.Bitcoin;

public class BitcoinJobManager : BitcoinJobManagerBase<BitcoinJob>
{
    public BitcoinJobManager(
        IComponentContext ctx,
        IMasterClock clock,
        IMessageBus messageBus,
        IExtraNonceProvider extraNonceProvider) :
        base(ctx, clock, messageBus, extraNonceProvider)
    {
    }

    private BitcoinTemplate coin;

    // TestnetTimeRoll: parent-header time cache (one getblockheader per new parent)
    private string timeRollParentHash;
    private ulong timeRollParentTime;

    private const uint MinDiffWindowSeconds = 20 * 60;

    // The 2-hour future limit that both Bitcoin consensus (MAX_FUTURE_BLOCK_TIME)
    // and miningcore's own share validator (BitcoinJob.ProcessShare, now + 7200)
    // enforce. A rolled nTime above this is rejected as too-far-in-the-future.
    private const uint MaxFutureSeconds = 2 * 60 * 60;

    // Headroom kept below the 2h ceiling: the block we eventually find is broadcast
    // some seconds/minutes after the job is built, and it must still be inside the
    // network's 2h window at broadcast time. Also absorbs miner ntime-rolling.
    private const uint RollFutureMarginSeconds = 10 * 60;

    private const string MinDiffBits = "1d00ffff";
    private const string MinDiffTarget = "00000000ffff0000000000000000000000000000000000000000000000000000";

    /// <summary>
    /// Testnet-only (BIP94 "20-minute Exception Rule"): instead of waiting out
    /// the 20-minute window in real time, stamp the job nTime = parent + 20min
    /// + 1s and mine at the minimum-difficulty target immediately. A block
    /// stamped past the boundary MUST carry min-difficulty nBits, so nTime and
    /// nBits are always overridden together. Fails open (honest template) if
    /// the parent header can't be resolved.
    ///
    /// Guarded by the 2h future ceiling: testnet4's tip timestamp drifts hours
    /// ahead of wall-clock (cumulative +20min-per-block), and when parent+20min
    /// would exceed now + 2h the min-difficulty exception is simply unavailable
    /// to anyone (the block would be too-far-future). In that regime we leave the
    /// honest template untouched rather than emit jobs whose shares/block would be
    /// rejected as "ntime out of range".
    /// </summary>
    private async Task ApplyTestnetTimeRollAsync(BlockTemplate template, CancellationToken ct)
    {
        if(extraPoolConfig?.TestnetTimeRoll != true || template == null)
            return;

        // hard mainnet refusal, independent of config
        if(network == NBitcoin.Network.Main)
            return;

        if(timeRollParentHash != template.PreviousBlockhash)
        {
            var response = await rpc.ExecuteAsync<Block>(logger,
                "getblockheader", ct, new object[] { template.PreviousBlockhash });

            if(response.Error != null || response.Response == null)
            {
                logger.Warn(() => $"TestnetTimeRoll: unable to resolve parent header {template.PreviousBlockhash}: {response.Error?.Message}");
                return;
            }

            timeRollParentHash = template.PreviousBlockhash;
            timeRollParentTime = response.Response.Time;
        }

        var minDiffTime = (uint) (timeRollParentTime + MinDiffWindowSeconds + 1);

        // already past the boundary: the daemon's template carries min-diff bits itself
        if(template.CurTime >= minDiffTime)
            return;

        // ceiling guard: only roll if the rolled nTime stays comfortably inside the
        // 2h future limit; otherwise the exception is unavailable — fall back honest.
        var nowUnix = (uint) ((DateTimeOffset) clock.Now).ToUnixTimeSeconds();
        var ceiling = nowUnix + MaxFutureSeconds - RollFutureMarginSeconds;

        if(minDiffTime > ceiling)
        {
            logger.Debug(() => $"TestnetTimeRoll: skipping height {template.Height} — rolled nTime {minDiffTime} is {(minDiffTime - nowUnix) / 60}min ahead of now, past the {(MaxFutureSeconds - RollFutureMarginSeconds) / 60}min ceiling (tip timestamp drift). Mining honest template.");
            return;
        }

        logger.Info(() => $"TestnetTimeRoll: rolling job for height {template.Height} to nTime {minDiffTime} (+{minDiffTime - template.CurTime}s) at min difficulty");

        template.CurTime = minDiffTime;
        template.Bits = MinDiffBits;
        template.Target = MinDiffTarget;
    }

    protected override object[] GetBlockTemplateParams()
    {
        var result = base.GetBlockTemplateParams();

        if(coin.BlockTemplateRpcExtraParams != null)
        {
            if(coin.BlockTemplateRpcExtraParams.Type == JTokenType.Array)
                result = result.Concat(coin.BlockTemplateRpcExtraParams.ToObject<object[]>() ?? Array.Empty<object>()).ToArray();
            else
                result = result.Concat(new []{ coin.BlockTemplateRpcExtraParams.ToObject<object>()}).ToArray();
        }

        return result;
    }

    protected async Task<RpcResponse<BlockTemplate>> GetBlockTemplateAsync(CancellationToken ct)
    {
        var result = await rpc.ExecuteAsync<BlockTemplate>(logger,
            BitcoinCommands.GetBlockTemplate, ct, extraPoolConfig?.GBTArgs ?? (object) GetBlockTemplateParams());

        return result;
    }

    protected RpcResponse<BlockTemplate> GetBlockTemplateFromJson(string json)
    {
        var result = JsonConvert.DeserializeObject<JsonRpcResponse>(json);

        return new RpcResponse<BlockTemplate>(result!.ResultAs<BlockTemplate>());
    }

    private BitcoinJob CreateJob()
    {
        return new();
    }

    protected override void PostChainIdentifyConfigure()
    {
        base.PostChainIdentifyConfigure();

        if(poolConfig.EnableInternalStratum == true && coin.HeaderHasherValue is IHashAlgorithmInit hashInit)
        {
            if(!hashInit.DigestInit(poolConfig))
                logger.Error(()=> $"{hashInit.GetType().Name} initialization failed");
        }
    }

    protected override async Task<(bool IsNew, bool Force)> UpdateJob(CancellationToken ct, bool forceUpdate, string via = null, string json = null)
    {
        try
        {
            if(forceUpdate)
                lastJobRebroadcast = clock.Now;

            var response = string.IsNullOrEmpty(json) ?
                await GetBlockTemplateAsync(ct) :
                GetBlockTemplateFromJson(json);

            // may happen if daemon is currently not connected to peers
            if(response.Error != null)
            {
                logger.Warn(() => $"Unable to update job. Daemon responded with: {response.Error.Message} Code {response.Error.Code}");
                return (false, forceUpdate);
            }

            var blockTemplate = response.Response;

            await ApplyTestnetTimeRollAsync(blockTemplate, ct);

            var job = currentJob;

            var isNew = job == null ||
                (blockTemplate != null &&
                    (job.BlockTemplate?.PreviousBlockhash != blockTemplate.PreviousBlockhash ||
                        blockTemplate.Height > job.BlockTemplate?.Height));

            if(isNew)
                messageBus.NotifyChainHeight(poolConfig.Id, blockTemplate.Height, poolConfig.Template);

            if(isNew || forceUpdate)
            {
                job = CreateJob();

                job.Init(blockTemplate, NextJobId(),
                    poolConfig, extraPoolConfig, clusterConfig, clock, poolAddressDestination, network, isPoS,
                    ShareMultiplier, coin.CoinbaseHasherValue, coin.HeaderHasherValue,
                    !isPoS ? coin.BlockHasherValue : coin.PoSBlockHasherValue ?? coin.BlockHasherValue);

                lock(jobLock)
                {
                    validJobs.Insert(0, job);

                    // trim active jobs
                    while(validJobs.Count > maxActiveJobs)
                        validJobs.RemoveAt(validJobs.Count - 1);
                }

                if(isNew)
                {
                    if(via != null)
                        logger.Info(() => $"Detected new block {blockTemplate.Height} [{via}]");
                    else
                        logger.Info(() => $"Detected new block {blockTemplate.Height}");

                    // update stats
                    BlockchainStats.LastNetworkBlockTime = clock.Now;
                    BlockchainStats.BlockHeight = blockTemplate.Height;
                    BlockchainStats.NetworkDifficulty = job.Difficulty;
                    BlockchainStats.NextNetworkTarget = blockTemplate.Target;
                    BlockchainStats.NextNetworkBits = blockTemplate.Bits;
                }

                else
                {
                    if(via != null)
                        logger.Debug(() => $"Template update {blockTemplate?.Height} [{via}]");
                    else
                        logger.Debug(() => $"Template update {blockTemplate?.Height}");
                }

                currentJob = job;
            }

            return (isNew, forceUpdate);
        }

        catch(OperationCanceledException)
        {
            // ignored
        }

        catch(Exception ex)
        {
            logger.Error(ex, () => $"Error during {nameof(UpdateJob)}");
        }

        return (false, forceUpdate);
    }

    protected override object GetJobParamsForStratum(bool isNew)
    {
        var job = currentJob;
        return job?.GetJobParams(isNew);
    }

    #region API-Surface

    public override void Configure(PoolConfig pc, ClusterConfig cc)
    {
        coin = pc.Template.As<BitcoinTemplate>();
        extraPoolConfig = pc.Extra.SafeExtensionDataAs<BitcoinPoolConfigExtra>();
        extraPoolPaymentProcessingConfig = pc.PaymentProcessing?.Extra?.SafeExtensionDataAs<BitcoinPoolPaymentProcessingConfigExtra>();

        if(extraPoolConfig?.MaxActiveJobs.HasValue == true)
            maxActiveJobs = extraPoolConfig.MaxActiveJobs.Value;

        hasLegacyDaemon = extraPoolConfig?.HasLegacyDaemon == true;

        base.Configure(pc, cc);
    }

    public virtual object[] GetSubscriberData(StratumConnection worker)
    {
        Contract.RequiresNonNull(worker);

        var context = worker.ContextAs<BitcoinWorkerContext>();

        // assign unique ExtraNonce1 to worker (miner)
        context.ExtraNonce1 = extraNonceProvider.Next();

        // setup response data
        var responseData = new object[]
        {
            context.ExtraNonce1,
            BitcoinConstants.ExtranoncePlaceHolderLength - ExtranonceBytes,
        };

        return responseData;
    }

    public virtual async ValueTask<Share> SubmitShareAsync(StratumConnection worker, object submission,
        CancellationToken ct)
    {
        Contract.RequiresNonNull(worker);
        Contract.RequiresNonNull(submission);

        if(submission is not object[] submitParams)
            throw new StratumException(StratumError.Other, "invalid params");

        var context = worker.ContextAs<BitcoinWorkerContext>();

        // extract params
        var workerValue = (submitParams[0] as string)?.Trim();
        var jobId = submitParams[1] as string;
        var extraNonce2 = submitParams[2] as string;
        var nTime = submitParams[3] as string;
        var nonce = submitParams[4] as string;
        var versionBits = context.VersionRollingMask.HasValue ? submitParams[5] as string : null;

        if(string.IsNullOrEmpty(workerValue))
            throw new StratumException(StratumError.Other, "missing or invalid workername");

        BitcoinJob job;

        lock(jobLock)
        {
            job = validJobs.FirstOrDefault(x => x.JobId == jobId);
        }

        if(job == null)
            throw new StratumException(StratumError.JobNotFound, "job not found");

        // validate & process
        var (share, blockHex) = job.ProcessShare(worker, extraNonce2, nTime, nonce, versionBits);

        // enrich share with common data
        share.PoolId = poolConfig.Id;
        share.IpAddress = worker.RemoteEndpoint.Address.ToString();
        share.Miner = context.Miner;
        share.Worker = context.Worker;
        share.UserAgent = context.UserAgent;
        share.Source = clusterConfig.ClusterName;
        share.Created = clock.Now;

        // if block candidate, submit & check if accepted by network
        if(share.IsBlockCandidate)
        {
            logger.Info(() => $"Submitting block {share.BlockHeight} [{share.BlockHash}]");

            var acceptResponse = await SubmitBlockAsync(share, blockHex, ct);

            // is it still a block candidate?
            share.IsBlockCandidate = acceptResponse.Accepted;

            if(share.IsBlockCandidate)
            {
                logger.Info(() => $"Daemon accepted block {share.BlockHeight} [{share.BlockHash}] submitted by {context.Miner}");

                OnBlockFound();

                // persist the coinbase transaction-hash to allow the payment processor
                // to verify later on that the pool has received the reward for the block
                share.TransactionConfirmationData = acceptResponse.CoinbaseTx;
            }

            else
            {
                // clear fields that no longer apply
                share.TransactionConfirmationData = null;
            }
        }

        return share;
    }

    public double ShareMultiplier => coin.ShareMultiplier;

    #endregion // API-Surface
}
