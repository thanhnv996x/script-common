# CRV V2 — Render video bằng thumbnail và cách tạo thumbnail

Tài liệu này dành cho người vận hành workspace **Crawl Render Video V2**. Nó giải thích hai việc trên màn hình:

1. **Step 7 — Thumbnail Generator**: tạo ảnh thumbnail cho từng video đã crawl.
2. **Step 8 — Render video**: lấy ảnh đó làm hình nền, loop theo độ dài nhạc, xuất file video.

Footage (ghép nhiều clip) là nhánh riêng trên cùng Step 8. Tài liệu này chỉ nói nhánh **Thumbnail**.

## Thumbnail dùng để làm gì

Một video render bằng thumbnail là một **ảnh tĩnh** được kéo thành video 1920×1080, rồi lặp cho đủ thời lượng nhạc crawl.

Ảnh đó có thể là:

- Ảnh do Step 7 vẽ (`thumbnail-0-final.png`, `thumbnail-1-final.png`, …): nền, ảnh nghệ sĩ, danh sách bài, chữ overlay.
- Ảnh gốc YouTube đã crawl (`thumbnail.jpg`), khi số output nhiều hơn số ảnh Step 7 tạo ra.

Sau khi render, file nằm trong thư mục video:

```text
{Thư mục output crawl}/{id video}/
  description.txt
  data.json
  thumbnail.jpg
  thumbnail-0-final.png
  thumbnail-1-final.png
  outputs/
    {id}-{thời gian} - mute.mp4
```

`*- mute.mp4` là video Step 8 xuất ra. Các bước sau (upload, add audio, …) dùng file này.

## Thứ tự làm

1. Crawl xong (Step 1). Mỗi video phải có thư mục riêng, trong đó có `description.txt`, `data.json`, file nhạc.
2. Chuẩn bị ảnh nền và ảnh nghệ sĩ (mục bên dưới).
3. Step 7: chọn style, bấm **GENERATE THUMBNAILS**.
4. Mở thư mục video, kiểm tra file `thumbnail-*-final.png` đã ra đúng ý.
5. Step 8: tick **Thumbnail**, chỉnh hiệu ứng và âm thanh, bấm **Bắt đầu render**.

Trong cùng một tab, gen thumbnail và render video **không chạy song song**. Đợi job hiện tại xong rồi bấm job kia.

## Chuẩn bị dữ liệu trước khi gen

Step 7 đi qua **mọi thư mục con** trong **Thư mục output crawl** của workspace. Mỗi thư mục được xử lý khi có đủ hai file:

| File | Nội dung app đọc |
|---|---|
| `description.txt` | Danh sách bài. Mỗi dòng đúng dạng `00:00:00 Tên bài - Nghệ sĩ`. Dấu phân tách là ` - ` (có khoảng trắng hai bên). |
| `data.json` | Có field `title`. Tiêu đề này được vẽ lên thumbnail style **DEFAULT**. |

Ví dụ một dòng description hợp lệ:

```text
00:00:00 Propuesta Indecente - Romeo Santos
00:03:12 Eres Mia - Romeo Santos
```

Tên nghệ sĩ sau dấu ` - ` phải **trùng tên thư mục ảnh** (mục sau). Thiếu một trong hai file, hoặc không tìm thấy ảnh nghệ sĩ nào, thư mục đó bị bỏ qua — console in lý do, các video khác vẫn chạy tiếp.

## Ảnh nền và ảnh nghệ sĩ

Cấu hình ở Step 7, mục **General Configuration**.

| Ô trên UI | Dùng cho |
|---|---|
| **Background Assets Path** | Ảnh nền `.png` / `.jpg`. Mỗi thumbnail lấy ngẫu nhiên một ảnh, kéo về 1920×1080. |
| **Thư mục ảnh nghệ sĩ** | Ảnh người (nên PNG nền trong suốt). |
| **Logos Path** | Logo thương hiệu cho style **VIEJITAS**. |
| **Batch Count** | Số ảnh tạo **cho mỗi** thư mục video. Giá trị `3` thì ra `thumbnail-0-final.png`, `thumbnail-1-final.png`, `thumbnail-2-final.png`. |

Cây thư mục ảnh nghệ sĩ:

```text
{Thư mục ảnh nghệ sĩ}/
  Romeo Santos/
    avatar-1.png
    avatar-2.png
  Prince Royce/
    avatar.png
```

Tên thư mục con phải khớp chữ nghệ sĩ trong `description.txt`. App chọn ngẫu nhiên một file `.png` hoặc `.jpg` trong thư mục đó.

Bấm **GENERATE THUMBNAILS** sẽ **xóa mọi file `*-final.png` cũ** trong thư mục video rồi tạo bộ mới. Muốn giữ bản cũ thì copy ra chỗ khác trước khi gen lại.

Nút **Gen** trên panel Thumbnail của Step 8 gọi cùng một lệnh với Step 7.

## Bốn style ảnh

Mục **Visual Style Selection**. Bật nhiều style thì **mỗi file** được random một style trong số style đang bật.

### DEFAULT

Layout theo template (nền, ảnh nghệ sĩ, tối đa 10 dòng bài, tiêu đề video).

- Bật **Chèn tên nghệ sĩ** thì vẽ thêm tên (lấy phần trước dấu phẩy).
- Một số template cần **ít nhất 3 nghệ sĩ có ảnh**. Nếu video ít nghệ sĩ hơn, app thử template khác (tối đa 10 lần) rồi bỏ qua file đó.

### VIEJITAS

Logo giữa hoặc lệch phải, hai cột (hoặc một cột) tên bài.

- Nếu **Logos Path** có file `.png`, app dùng logo đó thay cho ảnh nghệ sĩ.
- Logo chuẩn kích thước **1100×750** hoặc **1800×350** (hoặc gấp đôi 1100×750). Kích thước khác vẫn vẽ, nhưng bố cục random trong nhóm style 1–3.
- Style này làm sáng logo hơn các style kia.
- Không có ô profile riêng: chỉ cần ảnh nền + Logos Path + ảnh nghệ sĩ (để app biết video có nghệ sĩ).

### ROMEO

Cùng họ layout với VIEJITAS, nhưng:

- Dùng **ảnh nghệ sĩ**, phóng lớn.
- Luôn vẽ chữ overlay. Ô **Primary overlay text** là chữ đó. Để trống thì dùng tên nghệ sĩ được chọn.
- Chữ màu vàng, cỡ lớn, nằm trên logo.

### BACHATA

- Ô **Bachata text** là chữ lớn phía trên (mặc định kiểu `BACHATAS`). Dưới đó app luôn thêm dòng `Mix Romanticas`.
- **Chèn tên nghệ sĩ (Bachata)**: bật thì vẽ thêm tên nghệ sĩ được random từ những người có ảnh. Tắt thì chỉ còn Bachata text + Mix Romanticas + danh sách bài.
- Ảnh dùng là ảnh nghệ sĩ, không lấy logo trong Logos Path.

## Step 8 — render từ thumbnail

### 1. Chọn nguồn hình

Trong khối **Hình ảnh**, tick **Thumbnail**.

- Chỉ tick Thumbnail: mọi output render bằng thumbnail.
- Tick cả Thumbnail và Footage: mỗi output được random. Thanh **Tỷ lệ thumbnail / footage** là phần trăm rơi vào thumbnail (ví dụ 70 nghĩa là khoảng 70% output dùng thumbnail, phần còn lại dùng footage). Thanh này chỉ có ý nghĩa khi cả hai nguồn đều được tick.

### 2. Hiệu ứng trên ảnh (khi render, không phải lúc gen)

Các ô này áp lên ảnh **lúc render**, sau khi file `*-final.png` đã có.

| Ô | Kết quả |
|---|---|
| **Không hiệu ứng** | Giữ ảnh gốc, không blur. |
| **Blur nền** | Ảnh thu nhỏ, bo góc, đặt lên nền là chính ảnh đó đã làm mờ. |
| **Blur + lấp lánh** | Giống Blur nền, thêm vệt sáng chạy. |

Tick nhiều ô thì **mỗi output** random một kiểu trong số ô đang bật. Nên tick ít nhất một ô. Danh sách trống thì render báo lỗi cấu hình hiệu ứng.

**Hiệu ứng** (thư mục): chồng thêm clip/ảnh từ folder bạn chọn.

- **Similarity**: độ giống / độ lặp của lớp hiệu ứng.
- **Blend**: độ hòa lớp hiệu ứng với hình thumbnail.
- **X / Y**: vị trí đặt, trong khung 1920×1080.

**Nhận diện kênh** (cuối khối Tổng quát):

- **Logo + tên kênh**: chọn kênh, file logo, font, vị trí trên lưới.
- **Logo nhỏ góc dưới phải**: ảnh 50×50, cách lề phải và lề dưới 15px.

### 3. Số video xuất ra

Ô **Số output** là số file video cho **mỗi** link crawl.

Trước khi render, app **gán ảnh vào từng output**:

1. Gom mọi file `*-final.png` trong thư mục video.
2. Nếu ít hơn Số output, clone thêm từ `thumbnail.jpg` (không có thì clone từ ảnh `*-final.png` đầu tiên). File clone tên `thumbnail-original-0-final.png`, `thumbnail-original-1-final.png`, …
3. Xáo trộn rồi lấy đúng số lượng, mỗi ảnh thành một dòng output trên pipeline.
4. Thiếu cả `thumbnail.jpg` lẫn `*-final.png` thì **bỏ qua link đó** (không tạo output mới).

Hai ngoại lệ:

- **Tích lũy theo bài** / **Tách từng bài**: số output = số dòng timestamp trong description, không dùng ô Số output. Description phải có dòng `00:00:00 Tên bài - Nghệ sĩ`.
- **Nối các bài** (các kiểu songs concat): số output vẫn lấy từ ô Số output; mỗi output là một video nối toàn bộ các bài. Vẫn cần timestamp trong description. Nếu cần gán lại số slot, tắt **Bỏ qua output đã có video** rồi render.

**Bỏ qua output đã có video**:

- Bật: link đã có output thì giữ nguyên, không gán lại ảnh. Output đã có đường dẫn mute video thì không render lại.
- Tắt: app xóa danh sách output cũ, gán lại ảnh, render lại từ đầu. UI sẽ hỏi xác nhận trước khi chạy.

**% thời gian cắt**: cắt độ dài nhạc trước khi loop hình. Ví dụ dải 40–70% thì mỗi output giữ một tỷ lệ ngẫu nhiên trong khoảng đó. Mode theo bài hát không dùng thanh này.

Mỗi link còn phải có **file nhạc** (`crawlAudioFilePath`). Thiếu nhạc thì render dừng và báo cần nhập file nhạc.

### 4. Âm thanh

Hình thì loop từ thumbnail. Tiếng đi theo mục **Âm thanh** — cùng các lựa chọn với footage:

- **X2**: video dài gấp đôi cửa sổ nhạc (nửa đầu là nhạc crawl, nửa sau là nhạc khác / nhạc crawl / im lặng, tùy ô đang chọn).
- **X1**: một cửa sổ nhạc crawl, giữ tiếng, hoặc ghép thêm nhạc YouTube ở cuối file.

File `… - mute.mp4` là video hình. File audio đi kèm (concat) dùng cho bước add audio sau này.

### 5. Bấm render

**Bắt đầu render** xử lý lần lượt từng output chưa có mute video.

Với một output thumbnail, app làm lần lượt:

1. Chuẩn bị nhạc (mp3 → m4a, cắt theo % hoặc theo bài).
2. Áp hiệu ứng blur / lấp lánh lên ảnh đã gán.
3. Chồng logo kênh (nếu bật) và hiệu ứng thư mục (nếu bật).
4. Dựng khoảng **1 phút** video không tiếng từ ảnh đó.
5. Lặp đoạn 1 phút cho đủ độ dài nhạc, rồi gắn tiếng theo mục Âm thanh.
6. Ghi `outputs/{id}-{thời gian} - mute.mp4` và đánh dấu output thành công trên pipeline.

**Dừng sau output hiện tại** để output đang chạy xong rồi dừng, không cắt giữa file.

Bitrate và FPS ở khối **Tổng quát** áp cho file xuất ra.

## Việc nên kiểm tra khi ảnh hoặc video không ra

| Hiện tượng | Cách xử lý |
|---|---|
| Gen xong nhưng một video không có `*-final.png` | Mở console. Thường thiếu `description.txt` / `data.json`, hoặc không có thư mục ảnh trùng tên nghệ sĩ. |
| Description có bài nhưng app không nhận nghệ sĩ | Dòng phải có đúng một cụm ` - `. Tên nghệ sĩ sau cụm đó là tên folder. |
| DEFAULT bị bỏ qua | Video có dưới 3 nghệ sĩ có ảnh mà template random trúng layout cần 3 ảnh. Thêm ảnh, hoặc tắt DEFAULT và dùng VIEJITAS / ROMEO / BACHATA. |
| Ảnh nền trắng | **Background Assets Path** trống hoặc không có file `.png` / `.jpg`. |
| VIEJITAS không dùng logo brand | **Logos Path** phải là thư mục chứa file `.png`. |
| Render báo không tìm thấy thumbnail | Trong thư mục video không có `thumbnail.jpg` và cũng không có `*-final.png`. Gen lại hoặc để crawl giữ `thumbnail.jpg`. |
| Link không có dòng output mới | Số ảnh không đủ và không có nguồn để clone. Xem dòng log `Map thumbnails … bỏ qua`. |
| Bấm render mà video cũ không đổi | Đang bật **Bỏ qua output đã có video**, hoặc output đã có đường dẫn mute. Tắt bỏ qua (và xác nhận) nếu muốn làm lại. |
| Nút Gen / Render mờ | Tab đang chạy gen thumbnail, render draft, hoặc render output. Đợi xong. |

## Tóm tắt thao tác

1. Crawl xong, description đúng dạng `00:00:00 Bài hát - Nghệ sĩ`.
2. Step 7: trỏ ảnh nền, ảnh nghệ sĩ, (và Logos Path nếu dùng VIEJITAS). Đặt **Batch Count**. Bật style. Bấm **GENERATE THUMBNAILS**.
3. Soi file `thumbnail-*-final.png` trong từng thư mục video.
4. Step 8: tick **Thumbnail**, chọn hiệu ứng blur, số output, % cắt, kiểu âm thanh. Bấm **Bắt đầu render**.
5. Lấy video ở `{thư mục video}/outputs/… - mute.mp4`.
