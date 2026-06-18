using Microsoft.AspNetCore.Http;
using NLog;
using System.Net;
using Miningcore.Configuration;
using Miningcore.Extensions;

namespace Miningcore.Api.Middlewares;

public class IPAccessWhitelistMiddleware
{
    public IPAccessWhitelistMiddleware(RequestDelegate next, string[] locations, IPAddress[] whitelist, (IPAddress network, int prefixLength)[] networks, bool gpdrCompliantLogging)
    {
        this.whitelist = whitelist;
        this.networks = networks ?? Array.Empty<(IPAddress, int)>();
        this.next = next;
        this.locations = locations;
        this.gpdrCompliantLogging = gpdrCompliantLogging;
    }

    private readonly RequestDelegate next;
    private readonly ILogger logger = LogManager.GetCurrentClassLogger();
    private readonly IPAddress[] whitelist;
    private readonly (IPAddress network, int prefixLength)[] networks;
    private readonly string[] locations;
    private readonly bool gpdrCompliantLogging;

    public async Task Invoke(HttpContext context)
    {
        if(locations.Any(x => context.Request.Path.Value.StartsWith(x)))
        {
            var remoteAddress = context.Connection.RemoteIpAddress;
            // Normalize IPv4-mapped IPv6 (::ffff:a.b.c.d) so an exact/CIDR IPv4
            // entry still matches a pod connecting over a dual-stack socket.
            var normalized = remoteAddress != null && remoteAddress.IsIPv4MappedToIPv6
                ? remoteAddress.MapToIPv4()
                : remoteAddress;

            var allowed =
                whitelist.Any(x => x.Equals(remoteAddress) || x.Equals(normalized)) ||
                networks.Any(n => IsInCidr(normalized, n.network, n.prefixLength) || IsInCidr(remoteAddress, n.network, n.prefixLength));

            if(!allowed)
            {
                logger.Info(() => $"Unauthorized request attempt to {context.Request.Path.Value} from {remoteAddress.CensorOrReturn(gpdrCompliantLogging)}");

                context.Response.StatusCode = (int) HttpStatusCode.Forbidden;
                await context.Response.WriteAsync("You are not in my access list. Good Bye.\n");
                return;
            }
        }

        await next.Invoke(context);
    }

    // Dependency-free CIDR containment (avoids relying on a specific BCL/ASP.NET
    // IPNetwork type across target frameworks): compare the first prefixLength
    // bits of the address and the network base.
    private static bool IsInCidr(IPAddress address, IPAddress network, int prefixLength)
    {
        if(address == null || network == null)
            return false;

        var addrBytes = address.GetAddressBytes();
        var netBytes = network.GetAddressBytes();
        if(addrBytes.Length != netBytes.Length) // family mismatch (v4 vs v6)
            return false;
        if(prefixLength < 0 || prefixLength > addrBytes.Length * 8)
            return false;

        var fullBytes = prefixLength / 8;
        var remainingBits = prefixLength % 8;

        for(var i = 0; i < fullBytes; i++)
        {
            if(addrBytes[i] != netBytes[i])
                return false;
        }

        if(remainingBits > 0)
        {
            var mask = (byte) (0xFF << (8 - remainingBits));
            if((addrBytes[fullBytes] & mask) != (netBytes[fullBytes] & mask))
                return false;
        }

        return true;
    }
}
