# Get oSAIL type

You'll need a current oSAIL type to claim position rewards. To obtain it make a request to the
You can use `GET https://app.fullsail.finance/api/config` to get the list of all oSAIL types.

To find the current epoch oSAIL you find on oSAIL for which `o_sail.distribution_timestamp === current_epoch.start_time`.

oSAIL expires in 5 weeks from distribution start time.

Example response

```JSON
{
    "config": {
        "current_epoch": {
            "end_time": 1759363200000,
            "epoch_count": 4,
            "exercise_osail_apr": 0,
            "id": 46,
            "is_active": true,
            "osail_epoch_emissions": "0",
            "rebase_growth": "0",
            "start_time": 1758758400000
        },
        "global_voting_power": "901935489954825",
        "osail_tokens": [
            {
                "address": "0x04d2205d19315350ec3663a3225bd5947ab90511986ed8f2826c384b96b91cd3::osail_09oct2025::OSAIL_09OCT2025",
                "distribution_timestamp": 1756944000000,
                "expiration_timestamp": 1759968000000,
                "expired": false
            },
            {
                "address": "0x04d2205d19315350ec3663a3225bd5947ab90511986ed8f2826c384b96b91cd3::osail_16oct2025::OSAIL_16OCT2025",
                "distribution_timestamp": 1757548800000,
                "expiration_timestamp": 1760572800000,
                "expired": false
            },
            {
                "address": "0x04d2205d19315350ec3663a3225bd5947ab90511986ed8f2826c384b96b91cd3::osail_23oct2025::OSAIL_23OCT2025",
                "distribution_timestamp": 1758153600000,
                "expiration_timestamp": 1761177600000,
                "expired": false
            },
            {
                "address": "0x04d2205d19315350ec3663a3225bd5947ab90511986ed8f2826c384b96b91cd3::osail_30oct2025::OSAIL_30OCT2025",
                "distribution_timestamp": 1758758400000,
                "expiration_timestamp": 1761782400000,
                "expired": false
            },
            {
                "address": "0x04d2205d19315350ec3663a3225bd5947ab90511986ed8f2826c384b96b91cd3::osail_06nov2025::OSAIL_06NOV2025",
                "distribution_timestamp": 1759363200000,
                "expiration_timestamp": 1762387200000,
                "expired": false
            },
            {
                "address": "0x04d2205d19315350ec3663a3225bd5947ab90511986ed8f2826c384b96b91cd3::osail_13nov2025::OSAIL_13NOV2025",
                "distribution_timestamp": 1759968000000,
                "expiration_timestamp": 1762992000000,
                "expired": false
            },
            {
                "address": "0x04d2205d19315350ec3663a3225bd5947ab90511986ed8f2826c384b96b91cd3::osail_20nov2025::OSAIL_20NOV2025",
                "distribution_timestamp": 1760572800000,
                "expiration_timestamp": 1763596800000,
                "expired": false
            },
            {
                "address": "0x04d2205d19315350ec3663a3225bd5947ab90511986ed8f2826c384b96b91cd3::osail_27nov2025::OSAIL_27NOV2025",
                "distribution_timestamp": 1761177600000,
                "expiration_timestamp": 1764201600000,
                "expired": false
            },
            {
                "address": "0x04d2205d19315350ec3663a3225bd5947ab90511986ed8f2826c384b96b91cd3::osail_04dec2025::OSAIL_04DEC2025",
                "distribution_timestamp": 1761782400000,
                "expiration_timestamp": 1764806400000,
                "expired": false
            },
            {
                "address": "0x04d2205d19315350ec3663a3225bd5947ab90511986ed8f2826c384b96b91cd3::osail_11dec2025::OSAIL_11DEC2025",
                "distribution_timestamp": 1762387200000,
                "expiration_timestamp": 1765411200000,
                "expired": false
            },
            {
                "address": "0x04d2205d19315350ec3663a3225bd5947ab90511986ed8f2826c384b96b91cd3::osail_18dec2025::OSAIL_18DEC2025",
                "distribution_timestamp": 1762992000000,
                "expiration_timestamp": 1766016000000,
                "expired": false
            },
            {
                "address": "0x04d2205d19315350ec3663a3225bd5947ab90511986ed8f2826c384b96b91cd3::osail_25dec2025::OSAIL_25DEC2025",
                "distribution_timestamp": 1763596800000,
                "expiration_timestamp": 1766620800000,
                "expired": false
            },
            {
                "address": "0x04d2205d19315350ec3663a3225bd5947ab90511986ed8f2826c384b96b91cd3::osail_01jan2026::OSAIL_01JAN2026",
                "distribution_timestamp": 1764201600000,
                "expiration_timestamp": 1767225600000,
                "expired": false
            },
            {
                "address": "0x04d2205d19315350ec3663a3225bd5947ab90511986ed8f2826c384b96b91cd3::osail_08jan2026::OSAIL_08JAN2026",
                "distribution_timestamp": 1764806400000,
                "expiration_timestamp": 1767830400000,
                "expired": false
            },
            {
                "address": "0x04d2205d19315350ec3663a3225bd5947ab90511986ed8f2826c384b96b91cd3::osail_15jan2026::OSAIL_15JAN2026",
                "distribution_timestamp": 1765411200000,
                "expiration_timestamp": 1768435200000,
                "expired": false
            },
            {
                "address": "0x04d2205d19315350ec3663a3225bd5947ab90511986ed8f2826c384b96b91cd3::osail_22jan2026::OSAIL_22JAN2026",
                "distribution_timestamp": 1766016000000,
                "expiration_timestamp": 1769040000000,
                "expired": false
            },
            {
                "address": "0x04d2205d19315350ec3663a3225bd5947ab90511986ed8f2826c384b96b91cd3::osail_29jan2026::OSAIL_29JAN2026",
                "distribution_timestamp": 1766620800000,
                "expiration_timestamp": 1769644800000,
                "expired": false
            },
            {
                "address": "0x04d2205d19315350ec3663a3225bd5947ab90511986ed8f2826c384b96b91cd3::osail_05feb2026::OSAIL_05FEB2026",
                "distribution_timestamp": 1767225600000,
                "expiration_timestamp": 1770249600000,
                "expired": false
            },
            {
                "address": "0x04d2205d19315350ec3663a3225bd5947ab90511986ed8f2826c384b96b91cd3::osail_12feb2026::OSAIL_12FEB2026",
                "distribution_timestamp": 1767830400000,
                "expiration_timestamp": 1770854400000,
                "expired": false
            },
            {
                "address": "0x04d2205d19315350ec3663a3225bd5947ab90511986ed8f2826c384b96b91cd3::osail_19feb2026::OSAIL_19FEB2026",
                "distribution_timestamp": 1768435200000,
                "expiration_timestamp": 1771459200000,
                "expired": false
            }
        ],
        "server_time": 1758933793596
    }
}
```
