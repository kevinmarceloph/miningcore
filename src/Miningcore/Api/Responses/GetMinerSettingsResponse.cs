using System;
using System.Collections.Generic;

namespace Miningcore.Api.Responses
{
    public class MinerSettings
    {
        public string PaymentAddress { get; set; }
        public decimal PaymentThreshold { get; set; }
    }
}
