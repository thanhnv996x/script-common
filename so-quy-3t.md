# Sổ quỹ 3T — tóm tắt kỹ thuật

Sổ thu chi theo công ty, mặc định công ty **3T Media**. Số dư quỹ là số chạy từ các dòng đã xác nhận, tính trên ví đánh dấu `is_company_fund`. Ảnh bill chỉ thành dòng sổ sau khi parse và ghi (UI bắt xác nhận; Telegram ghi thẳng nếu đủ điều kiện).

Màn hình: `/admin/cashbook` (menu **Sổ quỹ 3T**). API prefix: `/api/v1/cashbook` (nhóm admin trong `routes/api/v1.php`).

## Luồng

```
Index.vue
  → Vuex Cashbook
    → resources/js/api/cashbook.api.js
      → CashbookController
        → CashbookRepository
          → CashbookLedger (công thức số dư)
          → CashbookCatalog (seed ví / nhóm / loại)
        → CashbookBillReader (Gemini)
        → CashbookExport (xlsx)
Cron cashbook:ingest-telegram-bills
  → CashbookTelegramInbox
    → CashbookBillReader → CashbookRepository::save
```

| Tầng | File |
|---|---|
| UI | `resources/js/components/admin/cashbook/Index.vue` |
| Route SPA | `resources/js/router/admins.js` (`name: cashbook`) |
| Store | `resources/js/store/modules/cashbook.store.js` |
| API client | `resources/js/api/cashbook.api.js` |
| Controller | `app/Http/Controllers/Api/V1/Admin/CashbookController.php` |
| Repository | `app/Repositories/Eloquents/CashbookRepository.php` |
| Công thức quỹ | `app/Services/Cashbook/CashbookLedger.php` |
| Danh mục mặc định | `app/Services/Cashbook/CashbookCatalog.php` |
| Đọc bill | `app/Services/Cashbook/CashbookBillReader.php` |
| Telegram | `app/Services/Cashbook/CashbookTelegramInbox.php` |
| Excel | `app/Services/Cashbook/CashbookExport.php` |
| Cron | `app/Console/Commands/CashbookIngestTelegramBillsCommand.php` |

Timezone tính toán: `Asia/Ho_Chi_Minh`.

## Phạm vi công ty

`resolveCompanyId`:

- User không phải admin/root chỉ thấy `users.company_id` của mình. Gửi `company_id` khác → 403.
- Admin/root chọn công ty trên filter. Không gửi thì lấy công ty tên `3T Media`, không có thì tên chứa `3T`, không có thì `firstOrCreate` công ty `3T Media`.

Catalog lần đầu (`CashbookCatalog::ensure`) chỉ chạy khi công ty chưa có ví.

## Cách dòng tiền vào quỹ

Cột `cashbook_entries.direction` lưu **behavior**, không lưu nhãn hiển thị. Nhãn nằm ở `cashbook_directions` (`direction_id`). Behavior hệ thống:

| Behavior | Nhãn | Delta quỹ (ví nguồn là quỹ công ty) | Vào cột năm |
|---|---|---|---|
| `opening` | Số dư đầu | `+amount` | không cộng Thu |
| `in` | Thu | `+amount` | Thu (`thu`) |
| `out` + `counts_as_cost` | Chi | `−amount` | Chi phí (`chi`) |
| `out` không tính CP, `draw`, `advance` | Chi / Rút / Ứng | `−amount` | Rút (`rut`) |
| `transfer` | Chuyển ví | trừ ví nguồn nếu là quỹ, cộng ví đích nếu là quỹ | Chuyển (`chuyen`), không vào Thu/Chi |

Dòng `status != confirmed` (đã hủy) có delta `0`. Ví `is_company_fund = false` không cộng vào quỹ 3T; số dư từng ví vẫn tính bằng `walletDelta`.

Số dư cuối tháng = đầu kỳ + `fund_delta` tháng đó, mang sang tháng sau. Dòng trước năm đang xem gộp vào số dư đầu tháng 1 (`prior`).

Thu theo tháng kiếm (`thu_earning`): dòng `in` có `earning_month` (`YYYY-MM`) cộng vào tháng kiếm, độc lập với tháng `booked_on`.

Chạy số dư trên từng dòng (`balance_after_vnd`) chỉ gắn khi list không lọc loại / từ khóa / ví (một tháng hoặc cả năm).

## Khóa, đối soát, quyết toán, trùng

- **Khóa tháng** (`cashbook_period_locks`, unique `company_id + year_month`): sửa, hủy, quyết toán, bật/tắt CP, lưu lương/thưởng đều bị chặn nếu tháng `booked_on` đã khóa. Telegram: ảnh vẫn lưu, không ghi sổ.
- **Đối soát ví** (`cashbook_reconciliations`, unique `company_id + wallet_id + as_of`): `as_of` là ngày cuối tháng đang đối soát. `diff = statement_vnd − balance_vnd`.
- **Quyết toán ứng**: chỉ dòng `advance`. Đổi thành `out`, `counts_as_cost = true`, gán nhóm (mặc định nhóm tên `Du lịch` nếu client không gửi). Ghi `settled_at`. Quỹ không trừ thêm vì tiền đã trừ lúc ghi ứng.
- **Tạm ứng còn treo**: `direction = advance`, `status = confirmed`, `settled_at` null, gom theo đối tác.
- **Trùng**: cùng công ty, ngày, ví, behavior, số tiền, status `confirmed`. UI trả 409, client gửi lại `allow_duplicate`. Telegram không ghi thêm.
- **Hủy**: soft-delete `status = void`, không xóa hàng. List ẩn dòng void.
- **Chi phí 3T**: chỉ bật/tắt trên dòng `out`. `opening` / `in` / `transfer` / `draw` bị ép `counts_as_cost = false` lúc lưu.

Audit append vào `audit_note`: `[Y-m-d H:i:s] mô tả`.

## Danh mục seed

Ví: `3T Momo`, `VPBank Thẻ`, `VCB Thành`, `VPBank Tâm`, `Momo`, `Zalo`, `Tiền mặt`, `NPT`, `Pingpong` (USD, kind `fx`).

Nhóm: Doanh thu kênh (thu); chi phí (mặt bằng, tài nguyên, ăn uống, lương, thưởng, đối tác, thiết bị, dịch vụ, mạng, AI/Veo, du lịch, hỗ trợ, phí quy đổi, khác); không tính CP: Trả nợ, Nạp ví, Rút cá nhân, Tạm ứng.

Loại giao dịch gợi ý: Chuyển khoản, QR, Tiền mặt. Nội dung, loại GD, đối tác được nhớ (`use_count`, `last_used_at`) mỗi lần ghi sổ — phục vụ gợi ý ô tìm.

User có thể thêm loại / nhóm / ví. Loại custom có `code` riêng nhưng `behavior` phải là một trong sáu behavior trên; lúc lưu, `direction` của dòng = behavior đó.

## Lương và thưởng

Nút **Lương** / **Thưởng** trên dòng khi tên nhóm hoặc nội dung chứa `lương` / `thưởng`.

**Lương cứng** (`cashbook_salary_lines`): tên hoặc `user_id` + `amount_vnd`. `fillCompanyStaff` chỉ lấy user công ty có `users.salary_vnd > 0` (cột thêm ở `2026_09_24_134000_add_salary_vnd_to_users_table.php`, sửa trên màn user). `apply_total` ghi đè `amount_vnd` của dòng sổ bằng tổng các dòng.

**Thưởng** (`savePayroll`): mỗi người tạo ba bản ghi cùng lúc:

1. `cashbook_channel_revenues` (`source = sheet`)
2. `cashbook_bonus_lines`
3. `cashbook_payroll_lines` (bản song song, lịch sử bảng dán)

Công thức:

```
profit_usd = update_usd × (1 − tax_percent/100) − other_deduction_usd
payout_usd = profit_usd × share_percent/100
payout_vnd = round(payout_usd × fx_rate_vnd)
```

`fx_rate` nhỏ hơn 1000 được nhân 1000 (nhập `25.5` → `25500`). Dòng nhãn chứa `tổng` hoặc `tong team` bị bỏ. Note chứa `chưa chi` → `pay_status = unpaid` và `cashbook_entry_id` null. Mở bảng trên dòng nội dung có `chưa chi` mà chưa có dòng gắn entry thì load các bonus `unpaid` của công ty.

Chính sách chia (`cashbook_share_policies` + `cashbook_share_tiers`) seed cho 3T Media, hiệu lực `2026-09-01`: mốc doanh thu USD 0–4999 → 15%, rồi 20% từ 5k, tăng 1 điểm mỗi 5k đến 25% ở 50–55k; trên 55k là offer riêng (`share_percent` null). Tháng đã chốt giữ `%` ghi trên dòng, không tính lại. API trả policy kèm payroll; UI không tự áp tier khi lưu.

**Preview doanh thu YM** `GET /revenue/ym-preview?month=YYYY-MM`: gom `ym_channels.maker_id` với `ym_channel_metric_monthly.revenue` theo tháng `YYYYMM`. Có route, chưa có hàm trong `cashbook.api.js`.

## Bill

Upload: ảnh jpg/jpeg/png/webp/gif, tối đa 8 MB, disk `local`, path `cashbook-bills/{company_id}/`. `CashbookBill::publishStoredFile` copy ra chỗ UI xem được.

Parse (`CashbookBillReader`): Gemini `generateContent`, model `config('services.gemini.model')` (mặc định `gemini-3.6-flash`), JSON mode, temperature 0. Prompt buộc direction ∈ `in|out|transfer|draw|advance`, map ví/nhóm theo tên catalog. Usage ghi qua `AiUsageRepository`. Không có `GEMINI_API_KEY` thì trả lỗi, user nhập tay.

UI: upload → parse → điền form → user bấm lưu (`source = bill`). Telegram: parse xong `save` luôn (`source = telegram`) nếu có số tiền, tháng chưa khóa, không trùng.

## Telegram

Lệnh: `php artisan cashbook:ingest-telegram-bills`.

Schedule (`app/Console/Kernel.php`): mỗi phút, timezone `Asia/Ho_Chi_Minh`, `withoutOverlapping(5)`.

Env: `TELEGRAM_CASHBOOK_BOT_TOKEN`, `TELEGRAM_CASHBOOK_CHAT_ID`. Offset lưu `storage/app/cashbook-telegram-offset.txt`. Chỉ nhận `message` đúng chat, có ảnh. Unique `(telegram_chat_id, telegram_message_id)`. Caption đưa vào hint parse và nối vào `content` nếu chưa có. Không khớp ví thì ví `Chưa rõ`. Reply lại message: đã ghi / lỗi / tháng khóa / trùng.

## Hỏi sổ

`POST /ask`: không gọi LLM. `CashbookLedger::answer` bắt từ khóa tiếng Việt (quỹ/số dư, thu, chi, rút, ứng, `tháng N`, tên nhóm) trên các dòng confirmed trong năm. Mặc định trả số dư cuối tháng hoặc cuối năm.

## Xuất Excel

`GET /export?year=&month=` → file `so-quy-3t-{year}.xlsx` (PhpSpreadsheet). Sheet: `Nam`, `So`, `Nhom`, `Tam ung`, `Vi`. Sheet nhóm lấy breakdown của tháng đang chọn (summary `asOfMonth`).

## API

Permission Spatie (gán `root`, `admin` lúc migrate): `api.cashbook.index|store|update|delete`. Menu hiện khi `$can('api.cashbook.index')` hoặc role admin/root.

| Method | Path | Permission | Việc |
|---|---|---|---|
| GET | `/catalog` | index | ví, nhóm, loại, đối tác, txn type, cụm nội dung |
| GET | `/summary` | index | 12 tháng, tổng năm, số dư ví, nhóm, tạm ứng |
| GET | `/entries` | index | dòng sổ, tối đa 500, có `balance_after_vnd` khi không lọc |
| GET | `/export` | index | xlsx |
| POST | `/periods/lock` | update | khóa / mở tháng |
| POST | `/reconcile` | store | số dư sao kê |
| POST | `/entries/{id}/settle` | update | quyết toán ứng |
| POST | `/entries/{id}/cost` | update | bật/tắt chi phí |
| GET | `/revenue/ym-preview` | index | doanh thu YM theo maker |
| GET/POST | `/entries/{id}/payroll` | index / update | đọc / lưu thưởng |
| POST | `/entries/{id}/salary` | update | lưu lương cứng |
| POST | `/directions` `/categories` `/wallets` | store | thêm danh mục |
| POST | `/entries/create` | store | ghi dòng |
| POST | `/entries/update/{id}` | update | sửa |
| DELETE | `/entries/delete/{id}` | delete | hủy (void) |
| POST | `/ask` | index | hỏi số |
| POST | `/bills/upload` | store | nhận ảnh |
| GET | `/bills/{id}/file` | index | file ảnh |
| POST | `/bills/{id}/parse` | store | Gemini |

Body tạo/sửa chính: `booked_on`, `direction` hoặc `direction_id`, `wallet_id`, `amount_vnd` (hoặc `amount_foreign × fx_rate_vnd`), `content`. Tuỳ chọn: `earning_month`, `counter_wallet_id` (bắt buộc khi transfer), `category_id`, `counterparty_name`, `txn_type`, `counts_as_cost`, `note`, `bill_id`, `allow_duplicate`.

List entries lọc `month` (`YYYY-MM`) hoặc `year`, cộng `direction`, `wallet_id`, `q` (nội dung, note, txn type, tên nhóm, tên đối tác).

## UI

Một trang `Index.vue` (Zenith: `ZenPage`, `ZenTree`, `ZenTable`, `ZenDialog`).

- Metric năm: thu, chi phí, rút/ứng/ngoài CP, số dư cuối năm.
- Cây Năm → Tháng (số dư cuối, khóa, đối soát) → Thu / Chi / Rút-chuyển → từng dòng (ngày, nội dung, nhóm, nguồn gửi, người nhận, tiền, quỹ sau dòng, CP, lương/thưởng, bill, sửa, hủy).
- Bảng đối soát ví, nhóm thu chi tháng đang chọn, tạm ứng còn treo.
- Dialog thêm/sửa dòng, dialog lương hoặc thưởng (dán bảng, sinh nhân viên, chênh sổ vs tổng dòng), dialog xem ảnh bill.
- Ô hỏi sổ gọi `/ask`.

## Bảng

Migration `database/migrations/2026_09_23_181000_create_cashbook_tables.php` trở đi:

| Bảng | Vai trò |
|---|---|
| `cashbook_wallets` | ví; `kind` bank/ewallet/cash/fx; `is_company_fund` |
| `cashbook_categories` | nhóm; `default_direction`, `counts_as_cost` |
| `cashbook_directions` | nhãn + behavior; `is_system` |
| `cashbook_counterparties` | người nhận / nguồn |
| `cashbook_txn_types` | loại giao dịch đã dùng |
| `cashbook_phrases` | nội dung đã dùng |
| `cashbook_bills` | ảnh + JSON gợi ý + telegram ids |
| `cashbook_entries` | dòng sổ |
| `cashbook_period_locks` | khóa tháng |
| `cashbook_reconciliations` | sao kê ví |
| `cashbook_salary_lines` | lương cứng theo dòng chi |
| `cashbook_payroll_lines` | bản thưởng dạng bảng dán |
| `cashbook_channel_revenues` | doanh thu USD theo người / tháng |
| `cashbook_revenue_channels` | nối doanh thu với `ym_channels` / metric tháng |
| `cashbook_bonus_lines` | % chia, payout, `pay_status` |
| `cashbook_share_policies` / `cashbook_share_tiers` | thang % theo doanh thu |

`cashbook_entries` đáng chú ý: `booked_on`, `earning_month`, `direction`, `direction_id`, `wallet_id`, `counter_wallet_id`, `amount_vnd`, `amount_foreign`, `fx_rate_vnd`, `counts_as_cost`, `status` (`confirmed`/`void`), `source` (`manual`/`bill`/`telegram`), `bill_id`, `settled_at`, `audit_note`, `performed_by_name`.

## Cấu hình

| Biến | Dùng cho |
|---|---|
| `GEMINI_API_KEY` | đọc bill |
| `GEMINI_MODEL` | mặc định `gemini-3.6-flash` |
| `GEMINI_HTTP_VERIFY` | mặc định tắt verify SSL |
| `TELEGRAM_CASHBOOK_BOT_TOKEN` | bot nhận ảnh |
| `TELEGRAM_CASHBOOK_CHAT_ID` | nhóm được ingest |
| `TELEGRAM_HTTP_VERIFY` | mặc định tắt verify SSL |
