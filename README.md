# w_management

## الإصدار 1.0.1 — 2026-10-30

فقدان صلاحية المدير يرفض الطلب برسالة واضحة دون حظر اللاعب. تُغلق القائمة عند تغير الدور، وتُهمل طلبات الإيداع والسحب بعد خروج الشخصية بأمان.

ما يحتاج تجربة داخل اللعبة: فتح القائمة ثم سحب رتبة المدير، وإرسال طلب بعد العودة لاختيار الشخصية.

Wraith Core RedM Boss & Gang Management

## Dependencies
- w_core
- w_lib (bundled in `[standalone]/w_lib`)

## Features
- Gang Management
- Boss Management
- Society Funds
- Hire / Fire Employees & Gang Members
- Promote / Demote Employees & Gang Members

Members are named by their fixed citizen id (w_lib's `w.citizen`): the member list shows it,
and promoting or dismissing works whether the member is in the game or not (an offline member's
saved row is updated, only while he still holds that job or gang). Recruiting picks a player
standing within 10 m; the server checks he is still near and logs him by citizen id.

## Language
The resource follows the library language (`w_lib:locale` convar, or the player's own
choice in the `/w_lib` dialog): Arabic or English. Every player-facing text lives in
`locales/ar.json` and `locales/en.json`; blip names and prompt labels are rebuilt when the
player switches language.

## Installation
- Download ALL Dependencies
- Import `w_management.sql`
- Put the script in the `[wraith]` directory.

## Issues & Suggestions
* This resource is still in development. All help with improving the resource is encouraged and appreciated
* Please use the issue tracker to report issues or make suggestions; keep `[Suggestion]` in the title for suggestions
