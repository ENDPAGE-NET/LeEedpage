# Stitch UI Design Prompt — 熵析云枢 (ENDPAGE Attendance)

## Product Overview

Enterprise attendance mobile app. Employees use face recognition + GPS to clock in/out. New accounts go through a setup wizard (change password + register face) before accessing the main app.

- Language: Simplified Chinese only
- Platform: iOS & Android (Flutter)
- Design system: Material 3

---

## Design Tokens

### Colors

| Token | Value | Usage |
|-------|-------|-------|
| Primary | Blue (Material 3 seed) | AppBar, buttons, links, active nav |
| On Primary | White | Text/icons on primary |
| Surface | White | Cards, sheets, backgrounds |
| On Surface | Dark grey/black | Body text |
| Success | Green `#4CAF50` | Normal status, completed steps, check-in confirmed |
| Warning | Orange `#FF9800` | Late (迟到) |
| Error | Red `#F44336` | Early leave (早退), validation errors |
| Muted | Grey 400 | Disabled states, placeholder text, dividers |

### Typography

| Style | Usage |
|-------|-------|
| Headline Medium + Bold | Page titles, large status text |
| Title Medium | Card headers, section titles |
| Body Medium | Default content text |
| Body Small | Captions, timestamps, secondary info |
| Label Large | Button text |

### Spacing & Radii

- Page padding: 16dp
- Card padding: 16dp
- Card radius: 12dp
- Button radius: pill (fully rounded) for primary actions, 8dp for secondary
- Element gap: 8–16dp
- Bottom nav height: default Material 3

---

## Screen Inventory (6 screens)

### 1. Login Screen — 登录

**Layout:** Centered form over gradient background (primary → surface, top to bottom).

**Elements:**
- App icon: fingerprint icon in white circle (size 80)
- App name: "熵析云枢" headline
- Subtitle: "企业考勤管理系统"
- Username field (prefixed person icon)
- Password field (prefixed lock icon, toggle visibility)
- "登录" full-width filled button
- Loading state: circular indicator replaces button text

**States:** Default / Validating / Error (red hint text below fields) / Loading

---

### 2. Setup Wizard — 账户设置

**Layout:** Scaffold with AppBar "账户设置", vertical card list + bottom activation button.

**Elements:**
- Step card ×2, each containing:
  - Step number circle (1, 2)
  - Title + description
  - Status icon: check circle (green) when done, chevron right when pending
  - Tap navigates to sub-screen
- Step 1: "修改密码" — lock icon
- Step 2: "注册人脸" — face icon
- Bottom: "激活账户" filled button, disabled until both steps complete

**States:** Both pending / One done / Both done (button enabled)

---

### 3. Password Change — 修改密码

**Layout:** Simple form page.

**Elements:**
- Current password field
- New password field
- Confirm password field
- "提交" filled button

**Validation:** Min 6 chars, confirm must match.

---

### 4. Face Registration — 人脸注册

**Layout:** Instructions + photo grid + submit button.

**Elements:**
- Instruction text: "请拍摄1-3张清晰面部照片（建议正面、左侧、右侧各一张）"
- Photo grid: 2 columns, max 3 slots
  - Empty slot: dashed border + camera icon + "添加照片"
  - Filled slot: image thumbnail + delete (×) button overlay
- "提交注册" filled button (enabled when ≥1 photo)

**States:** Empty / 1–3 photos selected / Uploading

---

### 5. Home (Check-in) — 打卡

**Layout:** Scaffold with AppBar "打卡", drawer menu, bottom navigation (2 tabs).

**Top section — User card:**
- CircleAvatar with first character of full name
- Full name + role tag
- Status badge (active/pending)

**Middle section — Today's status:**
- Two side-by-side status cards:
  - Left: 签到 (check-in) — time or "未签到"
  - Right: 签退 (check-out) — time or "未签退"
- Green text + check icon when recorded, grey when pending

**Action section:**
- Large circular "签到" button (primary, ~120dp diameter)
- Below: smaller "签退" outlined button
- Both trigger camera → capture face → submit with GPS

**Bottom section — Rules display:**
- Card showing current user's attendance rules
- Work time window, location requirement, work days

**Drawer:**
- User header: avatar, name, username
- "退出登录" list tile with logout icon

**Bottom Navigation:**
- Tab 1: 打卡 (fingerprint icon) — active
- Tab 2: 记录 (history icon)

---

### 6. History — 考勤记录

**Layout:** List view with pull-to-refresh, pagination.

**List item (card):**
- Left: type badge — "签到" (blue) / "签退" (teal)
- Center:
  - Date + time
  - Status chip: "正常" (green) / "迟到" (orange) / "早退" (red)
- Right: face score percentage (e.g. "98.5%")
- Optional: location verified icon

**Empty state:** Centered icon + "暂无考勤记录"

**Loading:** Shimmer placeholder or circular indicator at bottom for pagination

---

## Navigation Flow

```
App Launch
  │
  ├─ No token ──→ [Login]
  │                  │
  │                  └─ Success ──→ Check needsSetup
  │
  └─ Has token ──→ Fetch /users/me
                     │
                     ├─ needsSetup=true ──→ [Setup Wizard]
                     │                        ├→ [Password Change]
                     │                        ├→ [Face Registration]
                     │                        └→ Activate → [Home]
                     │
                     └─ needsSetup=false ──→ [Home]
                                              ├─ Tab 1: [Check-in]
                                              └─ Tab 2: [History]
```

---

## Component Library

| Component | Description |
|-----------|-------------|
| **StatusBadge** | Rounded chip with colored background. Variants: normal(green), late(orange), earlyLeave(red), pending(grey) |
| **StepCard** | Setup step row with number circle, title, description, done/pending indicator |
| **AttendanceStatusCard** | Shows single check-in or check-out status: icon + label + time |
| **RecordListItem** | History list card: type badge, datetime, status chip, face score |
| **PhotoSlot** | Square container for face photo: empty (dashed) or filled (image + delete) |
| **UserHeader** | Avatar circle + name + subtitle. Used in drawer and check-in page |
| **PrimaryActionButton** | Large circular filled button for check-in action |
| **RuleInfoCard** | Read-only card displaying attendance rules (time, location, work days) |

---

## Interaction Notes

- Check-in/check-out buttons open device camera immediately (no preview screen)
- GPS location is captured silently in background during camera capture
- Pull-to-refresh on check-in page and history page
- History list uses infinite scroll pagination (20 items per page)
- All form submissions show loading indicator and disable button
- Success/error feedback via bottom snackbar
- Face registration allows camera or gallery source on native, gallery only on web

---

## Iconography (Material Icons)

| Icon | Context |
|------|---------|
| `fingerprint` | App logo, check-in tab |
| `person` | Username field, avatar fallback |
| `lock` | Password fields, password change step |
| `face` | Face registration step |
| `camera_alt` | Photo capture |
| `check_circle` | Completed step, successful status |
| `history` | History tab |
| `logout` | Drawer logout |
| `location_on` | Location verified indicator |
| `access_time` | Time-related rule display |
| `refresh` | Manual refresh in AppBar |
