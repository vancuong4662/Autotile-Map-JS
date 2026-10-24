# Hệ thống Auto-Tile (dual-grid) và cách hiểu tileset

Tài liệu mô tả cách [index.html](./index.html) dùng texture nền và các tileset để tự chọn tile viền cho cát và nước.

## 1. Tổng quan

- Bản đồ là lưới `20 × 15` ô, mỗi ô `32 × 32 px`, lưu bằng `map[y][x]` với giá trị `'base' | 'sand' | 'water'`.
- **Nền (`base`)** là một texture lặp lại, nằm trong `texture/`. Có thể đổi bất kỳ lúc nào.
- **Cát và nước** là hai **lớp địa hình** vẽ chồng lên nền, mỗi lớp có một tileset riêng trong `tileset/`.
- Kỹ thuật dùng là **dual-grid**: tile hiển thị không nằm đúng trên ô dữ liệu mà đặt **lệch nửa ô** (16px), mỗi tile phủ 4 ô xung quanh một điểm góc. Nhờ đó chỉ cần **16 tile** (4 bit) thay vì 47 tile của blob autotile.

```
texture/
  grass.png          32×32, lặp liền mạch
  snow.png           32×32
tileset/
  tileset-sand.png   128×128, 4×4 tile, nền trong suốt
  tileset-water.png  128×128, 4×4 tile, nền trong suốt
```

## 2. Tài nguyên

### 2.1 Texture nền

- Ảnh `32 × 32 px`, phủ cả map bằng `ctx.createPattern(img, 'repeat')` nên **phải lặp liền mạch** (tileable).
- Khai báo trong `TEXTURES`; mỗi texture có `label` (tên hiển thị), `src` và `color` (màu ô mẫu trên nút bút vẽ):

```js
const TEXTURES={
  grass:{label:'Cỏ',   src:'texture/grass.png', color:'#648b38'},
  snow: {label:'Tuyết',src:'texture/snow.png',  color:'#eeeeee'}
};
```

- Thêm texture mới = bỏ ảnh vào `texture/` + thêm một dòng vào `TEXTURES`; nó tự xuất hiện trong ô chọn "Texture nền". Logic auto-tile không đổi.

### 2.2 Tileset

| Terrain | File |
|---|---|
| `sand` | `tileset/tileset-sand.png` |
| `water` | `tileset/tileset-water.png` |

Mỗi ảnh `128 × 128 px` = lưới `4 × 4` tile, mỗi tile `32 × 32 px`. **Phần nền (cỏ) đã bị xoá và là trong suốt (alpha = 0)**; chỉ còn cát/nước cùng viền của chúng (viền nâu của cát, bờ đá của nước). Hai tileset có cùng bố cục: tile ở `[cột, hàng]` luôn ứng với cùng một khóa góc.

### 2.3 Mỗi tile gồm 4 góc 16×16

```
┌────┬────┐
│ NW │ NE │   mỗi góc 16×16 px
├────┼────┤   góc "có địa hình" = cát/nước (opaque)
│ SW │ SE │   góc còn lại = trong suốt (lộ lớp bên dưới)
└────┴────┘
```

Tile được mô tả bằng khóa 4 bit theo thứ tự **NW NE SW SE**, `1` = góc đó là địa hình, `0` = không. Có đúng 16 tổ hợp, và tileset chứa đủ cả 16.

> Viền (mép nâu, bờ đá) nằm ở ranh giới giữa vùng địa hình và vùng trong suốt. Với nước, bờ đá còn lấn vào góc `0` của tile, nên không thể xác định khóa chỉ bằng việc đo độ phủ alpha mỗi góc — phải dùng bảng tra bên dưới.

### 2.4 Bố cục grid của tileset

Ký hiệu `[cột, hàng]`, tính từ `0`; khóa là NW NE SW SE.

| | cột 0 | cột 1 | cột 2 | cột 3 |
|---|---|---|---|---|
| **hàng 0** | `0010` SW | `0101` nửa E | `1011` thiếu NE | `0011` nửa S |
| **hàng 1** | `1001` chéo NW+SE | `0111` thiếu NW | `1111` đầy | `1110` thiếu SE |
| **hàng 2** | `0100` NE | `1100` nửa N | `1101` thiếu SW | `1010` nửa W |
| **hàng 3** | `0000` trống | `0001` SE | `0110` chéo NE+SW | `1000` NW |

Phân loại 16 tile:

- **Trống (1):** `0000` – hoàn toàn trong suốt, không vẽ.
- **Góc đơn (4):** `1000`, `0100`, `0010`, `0001` – góc ngoài lồi của một khối địa hình.
- **Nửa cạnh (4):** `1100` (N), `0011` (S), `1010` (W), `0101` (E) – cạnh thẳng.
- **Góc lõm (4):** `0111`, `1011`, `1101`, `1110` – thiếu đúng một góc.
- **Chéo (2):** `1001`, `0110` – hai góc đối diện, chỗ hai khối chạm nhau tại một điểm.
- **Đầy (1):** `1111` – ruột địa hình.

Bố cục này không theo thứ tự nhị phân; các tile xếp sao cho cả tileset ghép lại thành một bức tranh hồ/bãi cát hình ngôi sao. Vì vậy phải dùng bảng tra, không tính vị trí bằng công thức.

```js
// [cột, hàng] của tile trong ảnh, khóa theo thứ tự NW NE SW SE
const CORNER_TILE={
  '0000':[0,3],'1000':[3,3],'0100':[0,2],'0010':[0,0],'0001':[1,3],
  '1100':[1,2],'0011':[3,0],'1010':[3,2],'0101':[1,0],'1001':[0,1],'0110':[2,3],
  '1111':[2,1],'1011':[2,0],'0111':[1,1],'1110':[3,1],'1101':[2,2]
};
```

## 3. Quy luật auto-tile

### 3.1 Điểm góc và 4 ô quanh nó

Tile hiển thị `(tx, ty)` với `tx ∈ [0, COLS]`, `ty ∈ [0, ROWS]` (nhiều hơn số ô một hàng/cột để phủ biên) nằm tại pixel `(tx·32 − 16, ty·32 − 16)` và phủ 4 ô:

| Góc | Ô dữ liệu | Độ lệch `[dx, dy]` |
|---|---|---|
| NW | `(tx−1, ty−1)` | `[-1, -1]` |
| NE | `(tx, ty−1)` | `[0, -1]` |
| SW | `(tx−1, ty)` | `[-1, 0]` |
| SE | `(tx, ty)` | `[0, 0]` |

```
 ô(tx-1,ty-1) │ ô(tx,ty-1)
 ─────────────┼───────────── ← điểm góc (tx,ty)
 ô(tx-1,ty)   │ ô(tx,ty)        tile 32×32 phủ nửa mỗi ô
```

Ngược lại, một ô `(x, y)` nằm dưới 4 tile: nó là góc **NW** của tile `(x+1, y+1)`, **NE** của `(x, y+1)`, **SW** của `(x+1, y)` và **SE** của `(x, y)`. Khi sửa một ô, chỉ 4 tile này có thể đổi.

Ô nằm ngoài map được coi như ô sát biên gần nhất (clamp), nên địa hình chạm biên kéo dài ra ngoài thay vì tạo bờ ở mép.

### 3.2 Tính khóa

Với mỗi lớp và mỗi điểm góc, bit góc = `1` nếu ô tương ứng **cùng loại** với lớp đó:

```js
const CORNERS=[[-1,-1],[0,-1],[-1,0],[0,0]];   // NW NE SW SE
function cornerKey(tx,ty,type){
  let key='';
  for(const [dx,dy] of CORNERS) key += typeAt(tx+dx,ty+dy)===type ? '1' : '0';
  return key;
}
```

Ví dụ lớp `water`: ba ô NW, NE, SE là nước còn ô SW là nền → khóa `1101` → tile `[2,2]`. Ô thuộc loại khác (kể cả cát đứng cạnh nước) hay nền đều cho bit `0`.

### 3.3 Thứ tự và cách vẽ

1. Phủ texture nền lên cả map (pattern lặp).
2. Vẽ lần lượt các lớp theo `LAYER_ORDER = ['sand', 'water']` (nước nằm trên cát).
3. Với mỗi lớp, duyệt mọi điểm góc `(tx, ty)`: tính khóa, bỏ qua `0000`, tra `CORNER_TILE` rồi vẽ **nguyên tile 32×32**:

```js
const [col,row]=CORNER_TILE[key];
c.drawImage(tileset, col*32, row*32, 32, 32,
            tx*32-16, ty*32-16, 32, 32);
```

Vì phần không phải địa hình của tileset là trong suốt nên **không cần cắt từng góc hay kiểm tra ô bên dưới**: lớp bên dưới (nền, rồi cát) tự lộ ra. Hệ quả: viền đá của nước có thể phủ lên cát liền kề, và đổi texture nền không ảnh hưởng đến tileset.

### 3.4 Vì sao dual-grid chỉ cần 16 tile

Viền nằm **giữa hai ô**, tức tại đường chia các ô dữ liệu. Nếu đặt tile lệch nửa ô thì đường viền nằm trong lòng tile, và hình dạng viền chỉ phụ thuộc 4 ô góc (2⁴ = 16), không cần xét 8 hàng xóm như blob autotile. Ruột (`1111`) và trống (`0000`) là các tile không có viền.

## 4. Mở rộng

- **Thêm texture nền:** xem mục 2.1.
- **Thêm lớp địa hình mới** (ví dụ lava): tạo ảnh `128×128` cùng bố cục mục 2.4, nền trong suốt; thêm vào `TILESETS`, `LAYER_ORDER`, `TERRAIN_LABEL`, và thêm một nút bút vẽ có `data-brush` trùng tên.
- **Tileset có bố cục khác:** chỉ cần sửa `CORNER_TILE`; thuật toán (mục 3) không đổi.
- **Bố cục tileset trong trang** (mục "Bố cục grid của tileset") được dựng tự động từ `CORNER_TILE` bằng `buildSheetLayout`.

## 5. Giới hạn

- **Texture nền phải tileable:** `createPattern` lặp nguyên ảnh nên nếu ảnh không liền mạch sẽ lộ đường nối mỗi 32px.
- **Không có biến thể ruột:** tile `1111` chỉ có một mẫu nên vùng lớn lặp lại họa tiết đều đặn.
- **Cát và nước chạm nhau:** không có tile chuyển tiếp riêng; chỉ có viền của lớp nằm trên (nước) cắt lên cát.
- **Xuất PNG:** mở bằng `file://` thì canvas bị "tainted" do nạp ảnh từ file, `toBlob` bị chặn. Chạy qua HTTP server cục bộ để xuất được.

## 6. Tham chiếu mã

Trong [index.html](./index.html):

| Thành phần | Vai trò |
|---|---|
| `TEXTURES`, `TILESETS`, `LAYER_ORDER` | khai báo texture nền, tileset và thứ tự lớp |
| `CORNER_TILE` | bảng khóa 4 bit → `[cột, hàng]` |
| `CORNERS` | độ lệch `[dx, dy]` của 4 góc NW/NE/SW/SE |
| `typeAt` | đọc ô (clamp ở biên) |
| `cornerKey` | tính khóa của một tile |
| `drawLayer` | vẽ một lớp, nguyên tile 32×32 |
| `renderMap` | nền → các lớp → grid → con trỏ |
| `applyBaseTexture` | đổi texture nền và cập nhật giao diện |
| `buildSheetLayout` | dựng sơ đồ bố cục 4×4 trong trang từ `CORNER_TILE` |
