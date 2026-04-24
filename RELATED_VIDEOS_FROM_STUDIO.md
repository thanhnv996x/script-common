# CRV V2 — Related Videos từ YouTube Studio

Bản thiết kế + checklist cho chức năng **"Lấy video liên quan từ Studio Analytics"** nằm trong
Step 1 (Crawl Data) của workspace Crawl‑Render‑Video V2.

---

## 1. Bối cảnh & mục tiêu

- Hiện tại Step 1 cho phép người dùng:
  1. Dán danh sách link vào ô **"Danh sách links cần crawl"** (gọi các video này là `A, B, C, …`).
  2. Bấm **Map links** → backend parse và lưu vào bảng `video_links`.
  3. Bấm **Crawl links** → yt-dlp tải audio + metadata vào `crawledOutputFolder/<videoId>/`.
- Vấn đề: 10 link video gốc là không đủ để dựng kênh mới. Trong YouTube Studio Analytics, mỗi
  video có danh sách **"Videos liên quan" (YT_RELATED)** — đây chính là nguồn nội dung dồi dào.

### Mục tiêu

Cho 10 (hoặc `M`) video gốc có trong danh sách crawl, tự động lấy 10 (hoặc `N`) video liên quan
nhất từ Studio, crawl thông tin tất cả vào một thư mục staging **X**, rồi cho người dùng chọn
video nào "ổn" để promote sang `crawledOutputFolder` dùng trong pipeline chính.

**Toàn bộ luồng quản lý trong 1 modal** — 3 bước, mỗi bước 1 nút.

---

## 2. Thiết kế luồng 3 bước

### Bước 1 — Lấy `M × N` link liên quan từ Studio
- Input:
  - `sourceVideoIds`: list ID video gốc (auto fill từ `crawlLinks` đã Map, hoặc dán tay).
  - `topK`: số lượng top liên quan muốn lấy cho mỗi video gốc (default `10`).
  - `lookbackDays`: phạm vi ngày cho analytics (default `125` ≈ 4 tháng).
  - `channelFolderName`: kênh có cookie Studio để gọi API.
- Gọi `POST https://studio.youtube.com/youtubei/v1/yta_web/join` cho **từng** source video với
  payload rút gọn (xem mục 3).
- Parse `result[key='2__TOP_ENTITIES_TABLE_QUERY_KEY_TRAFFIC_SOURCE_DETAIL_ANALYTICS_REFERRER_VIDEO'].value.getCreatorVideos.videos`
  để lấy metadata của từng video liên quan.
- Ghi/Upsert vào bảng `crv2_related_videos` (mục 4).

### Bước 2 — Crawl `M × N` link bằng yt-dlp vào thư mục staging X
- Input:
  - `relatedCrawlOutputFolder` (thư mục X — tách khỏi `crawledOutputFolder`).
  - `useCookieForCrawl`, `jsRuntime`, `denoPath`: dùng chung với config của workspace.
- Với mỗi `related_video_id` có `crawl_status in {'', 'error'}`, chạy `yt-dlp` (tái dùng
  `reup_2.pipeline.crawl_ytdlp.crawl_video`) với output folder là `X/<videoId>/`.
- Cập nhật `crawl_status` = `'done'|'error'`, `crawl_error`, `crawled_at`.
- Đọc lại `data.json` để update `related_tags`, `related_description`, `related_channel_title`
  (do `getCreatorVideos` chỉ trả `channelId`, không trả title/tags/description).

### Bước 3 — Promote các video đã chọn sang `crawledOutputFolder`
- Người dùng chọn (checkbox) các dòng `A1, A2, …, B3 …` trong modal, bấm **Chuyển sang**
  `crawledOutputFolder`.
- Backend `shutil.move` từng thư mục `X/<videoId>/` → `crawledOutputFolder/<videoId>/`.
- Đồng thời append những link tương ứng vào `crawlLinks` (textarea) + tạo row trong
  `video_links` (giống Map links), để các bước sau (render/upload) dùng ngay được.
- Cập nhật `moved_to_main = 1`, `moved_at = NOW`.

---

## 3. Payload YT Studio tối thiểu

Mục tiêu: gọi **ít dữ liệu nhất** — chỉ cần list `A1, A2, … A{topK}`.

Từ `yta_web_response.curl` user cung cấp, cấu trúc đầy đủ dùng 9 nodes (bao gồm totals, charts,
channel info, playlist, product…). Ta rút còn **2 nodes + 1 connector**:

```jsonc
{
  "nodes": [
    {
      "key": "2__TOP_ENTITIES_TABLE_QUERY_KEY",
      "value": {
        "query": {
          "dimensions": [{"type": "TRAFFIC_SOURCE_DETAIL"}],
          "metrics": [
            {"type": "EXTERNAL_VIEWS", "includeTotal": true}
          ],
          "restricts": [
            {"dimension": {"type": "VIDEO"}, "inValues": ["<SOURCE_VIDEO_ID>"]},
            {"dimension": {"type": "TRAFFIC_SOURCE_TYPE"}, "inValues": ["YT_RELATED"]}
          ],
          "orders": [
            {"metric": {"type": "EXTERNAL_VIEWS"}, "direction": "ANALYTICS_ORDER_DIRECTION_DESC"}
          ],
          "timeRange": {
            "dateIdRange": {
              "inclusiveStart": 20251219,
              "exclusiveEnd":   20260423
            }
          },
          "limit": {"pageSize": <TOP_K>, "pageOffset": 0},
          "currency": "USD",
          "returnDataInNewFormat": true,
          "limitedToBatchedData": false
        }
      }
    },
    {
      "key": "2__TOP_ENTITIES_TABLE_QUERY_KEY_TRAFFIC_SOURCE_DETAIL_ANALYTICS_REFERRER_VIDEO",
      "value": {
        "getCreatorVideos": {
          "mask": {
            "videoId": true,
            "title": true,
            "channelId": true,
            "lengthSeconds": true,
            "timePublishedSeconds": true,
            "privacy": true,
            "metrics": {"all": true},
            "thumbnailDetails": {"all": true}
          }
        }
      }
    }
  ],
  "connectors": [
    {
      "extractorParams": {
        "resultKey": "2__TOP_ENTITIES_TABLE_QUERY_KEY",
        "resultTableExtractorParams": {"dimension": {"type": "TRAFFIC_SOURCE_DETAIL"}}
      },
      "fillerParams": {
        "targetKey": "2__TOP_ENTITIES_TABLE_QUERY_KEY_TRAFFIC_SOURCE_DETAIL_ANALYTICS_REFERRER_VIDEO",
        "idFillerParams": {}
      }
    }
  ],
  "allowFailureResultNodes": true,
  "context": { /* y hệt LIST_TOP_VIDEOS: client + request.eats + sessionInfo + user */ },
  "trackingLabel": "web_explore_video"
}
```

Giải thích connector:
1. `TOP_ENTITIES_TABLE_QUERY_KEY` trả về bảng các `TRAFFIC_SOURCE_DETAIL` (mỗi row là 1 ID của
   video liên quan) xếp theo `EXTERNAL_VIEWS` DESC.
2. Connector rút các `id` đó ra, bơm vào `…_ANALYTICS_REFERRER_VIDEO` (qua `idFillerParams`).
3. Node thứ 2 gọi `getCreatorVideos(ids=[…])` với mask tối thiểu → trả metadata video liên quan.

Trường metadata nhận được trên mỗi video liên quan:
- `videoId`, `title`, `channelId`, `lengthSeconds`, `timePublishedSeconds`, `privacy`,
  `metrics.viewCount`, `thumbnailDetails`.

> ⚠️ API **không** trả tags/description/channelTitle. Những trường này sẽ được bổ sung từ
> `data.json` do yt-dlp tải ở Bước 2 (tags nằm ở `data.json["tags"]`, channel name ở
> `data.json["channel"]` / `channel_name`).

---

## 4. Schema DB — bảng `crv2_related_videos`

Tạo additive (không tăng `user_version`) — pattern giống `_ensure_quick_schedule_schema`.

```sql
CREATE TABLE IF NOT EXISTS crv2_related_videos (
    id                        INTEGER PRIMARY KEY AUTOINCREMENT,
    workspace_id              INTEGER NOT NULL,
    source_video_id           TEXT    NOT NULL,  -- A, B, C…
    source_video_title        TEXT    NOT NULL DEFAULT '',
    related_video_id          TEXT    NOT NULL,  -- A1, A2, B1…
    related_title             TEXT    NOT NULL DEFAULT '',
    related_channel_id        TEXT    NOT NULL DEFAULT '',
    related_channel_title     TEXT    NOT NULL DEFAULT '',  -- populate sau khi yt-dlp
    related_tags_json         TEXT    NOT NULL DEFAULT '[]',-- populate sau khi yt-dlp
    related_description       TEXT    NOT NULL DEFAULT '',
    length_seconds            INTEGER NOT NULL DEFAULT 0,
    time_published_seconds    INTEGER NOT NULL DEFAULT 0,
    view_count                INTEGER NOT NULL DEFAULT 0,
    external_views_in_source  INTEGER NOT NULL DEFAULT 0,   -- views mà source đẩy tới related
    rank_in_source            INTEGER NOT NULL DEFAULT 0,   -- thứ tự 1..N
    privacy                   TEXT    NOT NULL DEFAULT '',
    thumbnail_url             TEXT    NOT NULL DEFAULT '',
    crawl_status              TEXT    NOT NULL DEFAULT '',  -- ''|'crawling'|'done'|'error'
    crawl_error               TEXT    NOT NULL DEFAULT '',
    crawled_at                TEXT    NOT NULL DEFAULT '',
    staging_folder_path       TEXT    NOT NULL DEFAULT '',  -- <X>/<videoId>
    moved_to_main             INTEGER NOT NULL DEFAULT 0,   -- 0|1
    moved_at                  TEXT    NOT NULL DEFAULT '',
    created_at                TEXT    NOT NULL,
    updated_at                TEXT    NOT NULL,
    UNIQUE(workspace_id, source_video_id, related_video_id)
);
CREATE INDEX IF NOT EXISTS idx_crv2_related_workspace
    ON crv2_related_videos(workspace_id);
CREATE INDEX IF NOT EXISTS idx_crv2_related_source
    ON crv2_related_videos(workspace_id, source_video_id);
```

---

## 5. Thư mục staging X

- Tên field lưu trong `settings`: `relatedCrawlOutputFolder`.
- Nếu rỗng, mặc định: `<crawledOutputFolder>/_related_staging`.
- Layout: `relatedCrawlOutputFolder/<relatedVideoId>/{data.json, audio.mp3, description.txt, thumbnail.jpg, …}`
  — **giống hệt** layout mà `crawl_ytdlp.crawl_video` tạo ra → Bước 3 chỉ cần `move` nguyên
  thư mục.

---

## 6. Cột hiển thị trong modal

| Cột                                | Sort? | Ghi chú                                                           |
| ---------------------------------- | :---: | ----------------------------------------------------------------- |
| ✅ Checkbox select                  |   —   | Multi select để Bước 3                                            |
| ID video gốc (A / B / …)           |  ✔︎   | `source_video_id` — cho phép nhóm                                 |
| ID video liên quan (A1, A2 …)      |  ✔︎   | `related_video_id`                                                |
| Views                              |  ✔︎   | `view_count` (tổng)                                               |
| Ngày đăng                          |  ✔︎   | `time_published_seconds` → `YYYY‑MM‑DD HH:MM` (Asia/Ho_Chi_Minh) |
| Đăng được bao lâu                  |       | Hậu tố `X năm Y tháng Z ngày` (tính client side)                  |
| Thời lượng                         |       | `length_seconds` → `HH:MM:SS`                                     |
| Tiêu đề                            |       | `related_title`                                                   |
| Tags                               |       | `related_tags_json` (hiển thị `#tag1 #tag2 …`) — sau Bước 2        |
| Tên kênh                           |       | `related_channel_title` — sau Bước 2                              |
| Trạng thái crawl                   |       | `crawl_status` (badge)                                            |
| Đã promote                         |       | `moved_to_main`                                                   |

Requirement của user: *"có chức năng sắp xếp theo id video 4 cột đầu tiên kia"* →
đánh dấu sortable ở 4 cột đầu (source id, related id, views, upload date).

---

## 7. API endpoints

Tất cả bổ sung theo pattern `CRV*V2`:

| Tên                                       | Args                                                                                     | Mô tả                               |
| ----------------------------------------- | ---------------------------------------------------------------------------------------- | ----------------------------------- |
| `CRVfetchRelatedVideosFromStudioV2`       | `workspaceId, channelFolderName, sourceVideoIds, topK, lookbackDays`                      | Bước 1 — gọi Studio + upsert DB     |
| `CRVcrawlRelatedVideosV2`                 | `workspaceId, relatedVideoIds` (rỗng = tất cả chưa done), `relatedCrawlOutputFolder`      | Bước 2 — chạy yt-dlp vào staging    |
| `CRVpromoteRelatedVideosV2`               | `workspaceId, relatedVideoIds`                                                            | Bước 3 — move + append crawlLinks   |
| `CRVlistRelatedVideosV2`                  | `workspaceId`                                                                             | Load toàn bộ rows cho modal         |
| `CRVdeleteRelatedVideosV2`                | `workspaceId, relatedVideoIds, alsoDeleteFolder`                                          | Xóa rows (tùy chọn xóa folder X)    |
| `CRVsaveRelatedVideosSettingsV2`          | `workspaceId, relatedCrawlOutputFolder, relatedTopK, relatedLookbackDays`                 | Lưu setting vào DB                  |

---

## 8. Checklist triển khai

### Backend

- [x] Viết tài liệu design + checklist (file này).
- [ ] **`ytstudio/__init__.py`**
  - [ ] Thêm template `LIST_RELATED_VIDEOS_BY_SOURCE` (nodes rút gọn + connector) trong `Templates.__init__`.
  - [ ] Thêm method `async def listRelatedVideosForSource(source_video_id, top_k, date_start, date_end)` trong `Studio` — tái dùng `context` của `LIST_TOP_VIDEOS`, parse `getCreatorVideos.videos` và trả `[(related_id, metadata…)]` kèm bảng views (từ `resultTable`) để gán `external_views_in_source`.
- [ ] **`reup_2/pipeline/related_videos_impl.py`** (module mới)
  - [ ] Helper `_ensure_related_videos_schema(conn)` — tạo bảng `crv2_related_videos` + index (idempotent).
  - [ ] `list_related_videos(workspace_id)` → `list[dict]`.
  - [ ] `save_related_videos_settings(workspace_id, folder, top_k, lookback_days)`.
  - [ ] `run_fetch_related_videos_from_studio(workspace_id, channel_folder_name, source_video_ids, top_k, lookback_days)` — dùng `Studio.initialize_studio` + song song hóa `listRelatedVideosForSource`, upsert row.
  - [ ] `run_crawl_related_videos(workspace_id, related_video_ids)` — resolve folder X, gọi `crawl_ytdlp.crawl_video`, parse `data.json` ra tags/description/channel, update row.
  - [ ] `run_promote_related_videos(workspace_id, related_video_ids)` — `shutil.move`, append `crawlLinks`, insert `video_links`, set `moved_to_main=1`.
  - [ ] `run_delete_related_videos(workspace_id, related_video_ids, also_delete_folder)`.
- [ ] **`DataService.py`** — 6 function `CRV*V2` tương ứng với API endpoints mục 7.
- [ ] **`app/api_handlers.py`** — 6 wrapper.
- [ ] **`app/handler_manifest.json`** — 6 entry (`name` + `args`).

### Frontend

- [ ] **`src/api/backendApi.js`** — 6 hàm `async export` gọi `fetch(${BASE}/<handler>, …)`.
- [ ] **`src/views/reup-2/crv2-workspace/components/steps/Crv2WorkspaceStep1CrawlData.vue`**
  - [ ] Thêm nút **"Lấy video liên quan (Studio)"** (icon `fa-solid fa-diagram-project`) trong `<aside>` — emit `open-related-videos`.
  - [ ] Thêm prop `:related-videos-busy`.
- [ ] **`src/views/reup-2/crv2-workspace/mixins/related-videos/crv2WorkspaceRelatedVideosMixin.js`** (module mới)
  - [ ] State: `relatedVideosDialogVisible`, `relatedVideosBusy` (fetch/crawl/promote cờ riêng), `relatedVideosRows`, `relatedVideosSelection`, form config (channel, sourceIds, topK, lookbackDays, relatedCrawlOutputFolder).
  - [ ] Methods: `openRelatedVideosDialog`, `refreshRelatedVideos`, `runFetchRelatedVideosFromStudio`, `runCrawlRelatedVideos`, `runPromoteRelatedVideos`, `runDeleteRelatedVideos`, `saveRelatedVideosSettings`.
- [ ] **`src/views/reup-2/crv2-workspace/components/dialogs/Crv2WorkspaceRelatedVideosDialog.vue`** (component mới)
  - [ ] Header + 3 phần (Fetch / Crawl / Promote) có thể collapse.
  - [ ] Form config (channel, topK, lookbackDays, relatedCrawlOutputFolder, sourceVideoIds multiline).
  - [ ] `<DataTable>` với sort 4 cột đầu, multi select, highlight row `moved_to_main=1`, badge `crawl_status`.
  - [ ] Footer buttons: Bước 1 / 2 / 3 — busy tách, `disabled` theo state.
- [ ] **`src/views/reup-2/CrawlRenderVideoV2WorkspacePanel.vue`**
  - [ ] Import + mount dialog, mount mixin.
  - [ ] Bind event `@open-related-videos="openRelatedVideosDialog()"` trên Step 1.

### Test thủ công

- [ ] Bước 1: gọi API trả đủ metadata cho ≥ 1 source video; lưu DB không trùng.
- [ ] Bước 2: yt-dlp tải thành công vào staging folder X, data.json có đủ tags/description/channel, row update.
- [ ] Bước 3: move folder thành công, `crawlLinks` textarea được append, row video_links được tạo.
- [ ] Modal sort theo 4 cột đầu hoạt động; selection/multi-select OK.
- [ ] Edge: `sourceVideoIds` rỗng → báo lỗi friendly; Studio trả lỗi auth → hiện toast rõ ràng.

---

## 9. Ghi chú rủi ro / edge case

1. Khi một `relatedVideoId` đã tồn tại ở nhiều `sourceVideoId` (ví dụ A1 = B3) — UNIQUE theo
   `(workspace, source, related)` → cho phép lưu 2 row; nhưng thư mục X chỉ 1 copy (vì cùng
   videoId). `promote` cần `skip` nếu folder đích đã tồn tại.
2. Quota Studio: API `yta_web/join` có rate limit. Mặc định song song `asyncio.Semaphore(5)` khi
   fetch `M` source videos.
3. Trong curl gốc, `context.client.clientVersion` là `1.20260422.03.00` — ta tái dùng
   `Templates.CLIENT` (đã fix sẵn phiên bản trong ytstudio). Nếu Studio nâng cấp, cần sync
   `clientVersion` ở cả 2 chỗ (đã có tiền lệ với `listTopVideos`).
4. `yt-dlp` có thể bị block theo region; code `crawl_ytdlp.crawl_video` đã có retry qua proxy —
   không cần đặc biệt cho feature này.
5. `crawledOutputFolder` và `relatedCrawlOutputFolder` phải khác nhau (backend check) để tránh
   nuốt video gốc khi promote.
