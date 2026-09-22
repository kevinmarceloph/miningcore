using Miningcore.Configuration;
using Newtonsoft.Json.Linq;

namespace Miningcore.Blockchain.Bitcoin.Configuration;

public class BitcoinPoolConfigExtra
{
    public BitcoinAddressType AddressType { get; set; } = BitcoinAddressType.Legacy;

    /// <summary>
    /// Maximum number of tracked jobs.
    /// Default: 12 - you should increase this value if your blockrefreshinterval is higher than 300ms
    /// </summary>
    public int? MaxActiveJobs { get; set; }

    /// <summary>
    /// Set to true to limit RPC commands to old Bitcoin command set
    /// </summary>
    public bool? HasLegacyDaemon { get; set; }

    /// <summary>
    /// Set to true to fall back to multiple sendtoaddress RPC calls for payments
    /// </summary>
    public bool HasBrokenSendMany { get; set; } = false;

    /// <summary>
    /// Arbitrary string appended at end of coinbase tx
    /// Overrides property of same name from BitcoinTemplate
    /// </summary>
    public string CoinbaseTxComment { get; set; }

    /// <summary>
    /// Testnet only (hard-refused on mainnet): exploit the testnet minimum-
    /// difficulty exception (BIP94 "20-minute Exception Rule") by stamping jobs
    /// nTime = parent + 20min + 1s with the min-difficulty target, instead of
    /// waiting out the window in real time. Consensus-valid: block timestamps
    /// only need to exceed MTP and stay within 2h of a validator's clock, and
    /// a block stamped past the boundary MUST carry min-difficulty nBits.
    /// </summary>
    public bool TestnetTimeRoll { get; set; } = false;

    /// <summary>
    /// Blocktemplate stream published via ZMQ
    /// </summary>
    public ZmqPubSubEndpointConfig BtStream { get; set; }

    /// <summary>
    /// Custom Arguments for getblocktemplate RPC
    /// </summary>
    public JToken GBTArgs { get; set; }
}
