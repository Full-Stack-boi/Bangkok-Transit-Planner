# 🚇 BKK Transit Planner

แอป Flutter สำหรับวางแผนการเดินทางด้วยระบบรถไฟฟ้ากรุงเทพ

## Features

- 🔍 **Route Planning** — ค้นหาและคำนวณเส้นทางที่เร็วที่สุดด้วย Dijkstra algorithm
- 🚉 **7 สายรถไฟฟ้า** — BTS (สุขุมวิท/สีลม/สีทอง), MRT (สีน้ำเงิน/สีม่วง/สีเหลือง), Airport Rail Link
- 💰 **ค่าโดยสารจริง** — คำนวณค่าโดยสารตามราคาจริงของแต่ละสาย
- ↔️ **บอกฝั่งที่ขึ้น** — เช่น "ไปสุวรรณภูมิ" หรือ "ไปพญาไท"
- ⏱️ **เวลาถัดไป** — คำนวณเวลารถไฟฟ้าขบวนถัดไป
- 👥 **Crowd Level** — GPS passive detection + peak hours
- 🌙 **Dark Mode** — ธีมมืดเป็นค่าเริ่มต้น

## Tech Stack

- **Flutter** — Cross-platform (iOS, Android, Web)
- **Riverpod** — State management (MVVM pattern)
- **Supabase** — Backend (Auth + Crowd data)
- **Dijkstra Algorithm** — Shortest path routing

## Architecture — MVVM

```
View (Screen/Widget)
  ↓ watches state, calls methods
ViewModel (StateNotifier/AsyncNotifier)
  ↓ calls
Repository / Service
  ↓ reads
Model (pure Dart, immutable)
```

## สายที่รองรับ

| สาย | สถานี | สี |
|---|---|---|
| BTS Sukhumvit | 47 | 🟢 |
| BTS Silom | 14 | 🟩 |
| BTS Gold | 3 | 🟡 |
| MRT Blue | 38 | 🔵 |
| MRT Purple | 16 | 🟣 |
| MRT Yellow | 23 | 🟡 |
| Airport Rail Link | 8 | 🔴 |

## Getting Started

```bash
flutter pub get
flutter run
```

## Project Status

- [x] Phase 1 — Foundation (MVVM, data, Dijkstra, theme)
- [x] Phase 2 — Core Features (search UI, route display)
- [x] Phase 3 — Map & Social (flutter_map, crowd, favorites)
- [x] Phase 4 — Polish (notifications, i18n, testing)

## Testing

แอปนี้มาพร้อมกับระบบการทดสอบที่ครอบคลุม:
- 🧪 **Unit Tests** ([router_test.dart](file:///F:/Project/Train/test/router_test.dart)): ทดสอบความถูกต้องของเส้นทาง Dijkstra และการเปลี่ยนสายในโครงข่ายรถไฟฟ้า
- 📱 **Widget Tests** ([widget_test.dart](file:///F:/Project/Train/test/widget_test.dart)): ทดสอบความสมบูรณ์ในการเรนเดอร์ UI และระบบนำทางสลับแท็บโดยใช้ Mock Providers

รันการทดสอบด้วยคำสั่ง:
```bash
flutter test
```
