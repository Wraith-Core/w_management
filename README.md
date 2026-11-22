# w_management

Job boss and gang society treasury management (`management_funds`) for **Wraith Framework RedM**.

## Key Features

- Persistent society accounts for jobs and gangs.
- Simple server exports for depositing, withdrawing, and querying account balances.

## Installation

1. Import `w_management.sql` into your database.
2. Place `w_management` in `resources/[wraith]/w_management`.
3. Add `ensure w_management` to `server.cfg` after `w_lib` and `w_core`.

## Server Exports

```lua
local balance = exports.w_management:GetAccount('police')
exports.w_management:AddMoney('police', 500)
exports.w_management:RemoveMoney('police', 100)

local gangBal = exports.w_management:GetGangAccount('example')
exports.w_management:AddGangMoney('example', 250)
exports.w_management:RemoveGangMoney('example', 50)
```

## Documentation & Links

- **Developer Docs:** https://wraith-core.github.io/docs/#/resources/economy-jobs
- **txAdmin Recipe:** https://github.com/Wraith-Core/txAdminRecipe

## License

GPL-3.0 — see [LICENSE](LICENSE).
