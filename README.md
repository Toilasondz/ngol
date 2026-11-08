# VideoStarTool HSON — 3-Feature Menu v5.0.0 (Bản Đã Fix 100% & Ký Được)

Dự án tinh chỉnh (iOS tweak dynamic library) độc lập dành cho **Video Star**, phát triển bởi **HSON**.
Cung cấp 3 tính năng tự động native cao cấp:
1. **Auto nhập ảnh** (`startFeatureReplaceMedia`)
2. **Auto chia beat** (`startFeatureBeatSplit`)
3. **Auto nhập phân cảnh** (`startFeatureMultiSceneApply`)

---

## 🛠 Danh sách các lỗi đã được sửa triệt để

### 1. Sửa lỗi Ký Code (Codesign & zsign Fix - Ký được 100%)
- **Nguyên nhân lỗi cũ**: Lỗi `Can't find CodeSignature segment` / `Can't find free space of LoadCommands` xảy ra khi công cụ ký (zsign, ESign, Scarlet, Sideloadly) cố chèn lệnh ký `LC_CODE_SIGNATURE` vào header Mach-O nhưng không có đủ khoảng trống dự phòng trước segment `__TEXT`.
- **Giải pháp**:
  - Thêm cờ linker `-Wl,-headerpad_max_install_names` và `-Wl,-headerpad,0x4000` (dành riêng 29 KB khoảng trống trong Load Commands).
  - Tích hợp cờ `-adhoc_codesign` khi build và cấu hình `codesign -f -s -` / `ldid -S` trong CI GitHub Actions.
  - File dylib biên dịch ra **đã có sẵn `LC_CODE_SIGNATURE`**, các công cụ ký như `zsign`, `ESign`, `Scarlet`, `TrollStore`, `Feather`, `Sideloadly` sẽ thay thế chữ ký trực tiếp trong 1 giây mà **không bao giờ bị lỗi tràn load command**.

### 2. Sửa lỗi Runtime & Nhận diện ứng dụng (Hoạt động 100%)
- **Bỏ giới hạn cứng Bundle ID**: Phiên bản trước chỉ chạy khi bundle ID đúng chính xác `com.frontierdesign.videostar1` khiến tweak không bao giờ hiện nút menu khi cài trên App Store (`com.frontierdesign.videostar`) hoặc khi người dùng đổi tên bundle ID để sideload. Đã mở rộng hỗ trợ tất cả các biến thể bundle ID của Video Star.
- **Cập nhật Filter Hook (`HSONModernMenu.plist`)**: Bổ sung `com.frontierdesign.videostar`, `com.cameraxis.videostar` và `VideoStar` để Cydia Substrate, ElleKit và Dopamine tự động nạp tweak chính xác.
- **Nút nổi HS hỗ trợ kéo thả (`UIPanGestureRecognizer`)**: Nút nổi tròn "HS" nay có thể kéo di chuyển tự do trên màn hình để tránh che các nút quan trọng của Video Star, tự động bám lề an toàn và ghi nhớ vị trí sau khi thoát app qua `NSUserDefaults`.
- **Sửa xung đột cảm ứng Menu**: Tách độc lập lớp nền mờ (`dimView`) và bảng điều khiển (`panel`) giúp các thao tác chạm vào card tính năng và chuyển tab mượt mà, không bị tắt menu nhầm.
- **Hệ thống tìm kiếm ViewController thông minh (`VSFindViewController`)**: Duyệt đệ quy toàn bộ UINavigationController, UITabBarController, modal presentation và các cửa sổ con. Khắc phục triệt để lỗi báo nhầm *"Bạn chưa trong phần nhiều lớp h/ả"* hoặc *"Bạn chưa trong phần chia phân cảnh"*.
- **Tự động hóa hoàn toàn chức năng Phân Cảnh (Feature 3)**:
  - Tự động gọi selector `@selector(create)` của Video Star hoặc tìm nút Tạo/Create trong subview để hoàn tất phân cảnh và tự động chuyển tiếp phân cảnh tiếp theo.
- **Bảo toàn phản hồi Media (`VSCloneResponse`)**: Tự động fallback về đối tượng phản hồi gốc nếu class clone bị lỗi, đảm bảo 100% lớp ảnh/video được cập nhật.
- **Tự động giải phóng trạng thái (`_activeFeature`)**: Đảm bảo không bao giờ bị kẹt thông báo *"HSON đang chạy"*.

---

## 📁 Cấu trúc Thư mục

```
VideoStarTool_HSON_3Features_v5/
├── HSONModernMenu.dylib     # File dylib đã biên dịch & ký sẵn LC_CODE_SIGNATURE
├── build.ps1                # Script biên dịch 1-click trực tiếp trên Windows
├── Makefile                 # Script biên dịch Theos (macOS / Linux)
├── control                  # Metadata đóng gói DEB Cydia / Sileo
├── HSONModernMenu.plist     # Filter injection cho Substrate / ElleKit
├── Source/
│   ├── Tweak.m              # Giao diện nút nổi, bảng menu HSON, quản lý cảm ứng
│   └── Features/
│       ├── HSONFeatureEngine.h
│       └── HSONFeatureEngine.m # 3 tính năng tự động tương tác sâu với Video Star
└── .github/workflows/
    └── main.yml             # Workflow CI GitHub Actions tự động build dylib & deb
```

---

## 🚀 Hướng dẫn Sử dụng & Đóng gói vào Video Star

### Cách 1: Sử dụng File Dylib Đã Build Sẵn
File `HSONModernMenu.dylib` đã được biên dịch và nhúng sẵn mã chữ ký. Bạn chỉ cần:
1. Dùng **Sideloadly** / **ESign** / **Scarlet** / **TrollStore** / **Azule** chèn file `HSONModernMenu.dylib` vào file IPA của Video Star.
2. Cài đặt IPA lên máy và mở Video Star: nút tròn nổi **HS** sẽ xuất hiện trên màn hình!

### Cách 2: Tự Biên dịch Lại Trên Windows (1-Click)
Mở PowerShell tại thư mục này và chạy:
```powershell
powershell -ExecutionPolicy Bypass -File .\build.ps1
```
File dylib mới sẽ được tạo tại `out\HSONModernMenu.dylib` và sao chép ra thư mục gốc.

### Cách 3: Build Bằng Theos (macOS / Linux / GitHub Actions)
Chạy lệnh:
```bash
make clean
make package FINALPACKAGE=1
```
Hoặc push code lên GitHub repo để GitHub Actions `.github/workflows/main.yml` tự động build ra file `.deb` và `.dylib` trong phần Releases / Artifacts.
