# Mammod TMS — Backend

Backend ของ [Mammod_FrontEnd](https://github.com/Supakk/Mammod_FrontEnd)
เขียนด้วย ASP.NET Core (net8.0) ตาม stack เดียวกับ `KM_BE_Dev/OMS_KMTo` ของทีม

ตอนนี้ข้อมูลเก็บ **ในหน่วยความจำ** ยังไม่มีฐานข้อมูล — รีสตาร์ทแล้วข้อมูลกลับไปเป็นค่าตั้งต้น
กติกาทางธุรกิจทั้งหมดของจริงอยู่ครบแล้ว ที่ขาดคือที่เก็บถาวร

---

## รันยังไง

ต้องมี [.NET SDK 8 ขึ้นไป](https://dotnet.microsoft.com/download) (เครื่องที่ตั้งไว้ใช้ 9.0.312 ซึ่ง build net8.0 ได้)

```bash
cd Mammod_BackEnd
dotnet run
```

ขึ้นที่ `http://localhost:5080` — เปิด `http://localhost:5080/swagger` จะเห็น endpoint ทั้งหมด
กดยิงทดสอบได้จากหน้านั้นเลย ไม่ต้องเปิด frontend

ระหว่างพัฒนาใช้ `dotnet watch` แทน จะ compile ใหม่ให้อัตโนมัติทุกครั้งที่เซฟ

### ต่อกับ frontend

ในโปรเจค frontend สร้างไฟล์ `.env` (มีให้แล้ว):

```
VITE_API_BASE_URL=http://localhost:5080
VITE_API_LIVE=auth,manifests,transportPlans,...
```

แล้ว `npm run dev` ตามปกติ ฝั่ง frontend **ไม่ต้องแก้โค้ดเลยสักบรรทัด** —
ทุก `api/xxx.ts` มีทั้งตัว mock และตัวยิง HTTP อยู่แล้ว และเลือกด้วยค่าใน `.env`

> ⚠️ ต้องรันทั้งสองตัวพร้อมกัน: backend ที่ 5080 และ frontend ที่ 5700
> ถ้า backend ไม่ขึ้น ทุกจอจะว่างเปล่าพร้อมข้อความ "เชื่อมต่อเซิร์ฟเวอร์ไม่สำเร็จ"

---

## โค้ดอยู่ตรงไหน

อ่านตามลำดับนี้จะเข้าใจเร็วที่สุด

| โฟลเดอร์ | หน้าที่ | เริ่มอ่านที่ |
| --- | --- | --- |
| `Program.cs` | ตั้งค่าทุกอย่างและลำดับการทำงานของ request | ไฟล์เดียว อ่านบนลงล่าง |
| `Models/` | หน้าตาข้อมูล — แปลงมาจาก type ฝั่ง frontend ทีละฟิลด์ | `Logistics.cs` |
| `Dtos/` | หน้าตา **ที่ client ส่งเข้ามาได้** ซึ่งแคบกว่า Model | `Requests.cs` |
| `Data/` | ที่เก็บข้อมูล + **กติกาทางธุรกิจทั้งหมด** | `TmsStore.cs` ← หัวใจ |
| `Controllers/` | รับ request แล้วส่งต่อให้ `Data/` ไม่มีตรรกะของตัวเอง | `ManifestsController.cs` |
| `Middleware/` | แปลง exception เป็น JSON ที่ client อ่านออก | `ErrorHandling.cs` |
| `Services/` | ออก token ตอน login | `TokenService.cs` |

### ทำไมกติกาไม่อยู่ใน Controller

Controller มีหน้าที่แค่แกะ request แล้วส่งต่อ ส่วน "ยืนยันใบไม่ได้ถ้ายังไม่มีรถ"
อยู่ใน `TmsStore` ที่เดียว ถ้ากระจายไว้ทั้งสองที่ วันหนึ่งมันจะไม่ตรงกัน
แล้วไม่มีใครรู้ว่าอันไหนถูก

### สามคำที่เจอบ่อยใน ASP.NET Core

- **Controller** — คลาสที่ผูกกับ URL เช่น `[Route("manifests")]` คือทุก path ที่ขึ้นต้นด้วย `/manifests`
- **DI (Dependency Injection)** — เขียน `ManifestsController(TmsStore store)` แล้ว framework
  หา `TmsStore` มาส่งให้เอง เพราะลงทะเบียนไว้ใน `Program.cs` ด้วย `AddSingleton`
- **Middleware** — ด่านที่ request ทุกอันต้องผ่าน เรียงตามลำดับที่เขียนใน `Program.cs`

---

## กติกาที่ backend บังคับ

กติกาพวกนี้ **ต้องอยู่ฝั่งเซิร์ฟเวอร์** ต่อให้ฝั่งจอปิดปุ่มไว้แล้วก็ตาม —
ปุ่มที่กดไม่ได้เป็นความสุภาพ ไม่ใช่กฎ ใครยิง API ตรงก็ข้ามมันได้

| กติกา | อยู่ที่ |
| --- | --- |
| ใบสั่งส่งอยู่ได้ที่เดียว — คิว, ในแผน, หรือบนใบปิดบรรทุก ทุกก้าวคือ "ย้าย" | `TmsStore.GiveBack` / `TakeFromPool` |
| ยืนยันไม่ได้ถ้ายังไม่มีรถ คนขับ และสายส่ง | `Manifest.IsAssigned()` |
| แก้ไขได้ถึงสถานะ `confirmed` · ปิดเมื่อ `sent` | `AssertStatus` ใน `UpdateManifest` |
| แยกใบ / ย้ายจุดส่ง เฉพาะ `draft` เพราะเขียนเอกสารสองใบพร้อมกัน | `SplitManifest` / `MoveStops` |
| เปิดอินวอยซ์ได้เฉพาะหลังส่ง MMX แล้ว | `MarkInvoiced` |
| `เสร็จสิ้น` / `ตีกลับ` มาจาก OMS เท่านั้น TMS ตั้งเองไม่ได้ | `ApplyExternalStatus` |
| ยกเลิกไม่ต้องมีเหตุผล และช่องว่างไม่นับเป็นเหตุผล | `CancelManifest` |
| ยกเลิกแผน/ใบ → ใบสั่งส่งเด้งกลับคิวทั้งหมด | `CancelPlan` / `CancelManifest` |
| **สีเส้นทางเซิร์ฟเวอร์เป็นคนแจก** ไม่ใช่ client — และรักษาไว้ตอนแก้ไข | `CreateManifest` / `UpdateManifest` |
| ค่าขนส่งคิดจาก `tripPrice + priceAdd - priceDeduct` ไม่รับตัวเลขที่ client พิมพ์มา | `FreightPricing.Total()` |
| รหัสคลัง / โซน / สายส่ง / ผู้ให้บริการ / ทะเบียนรถ ห้ามซ้ำ | `Assert…Free` แต่ละตัว |
| หนึ่งอำเภออยู่ได้โซนเดียว | `AssertAreasFree` |
| secret ส่งกลับเป็น mask เสมอ ไม่เคยส่งค่าจริง | `IntegrationConfigStore` |

---

## เรื่องที่ตั้งใจทำแบบนี้

**ทำไม error message เป็นภาษาไทย** — `apiClient.ts` ฝั่ง frontend อ่าน field `message`
จาก body ก่อนจะไปใช้ข้อความสำรองจาก status code ข้อความที่เขียนที่นี่จึงไปโผล่หน้าจอตรง ๆ
เหตุผลที่ปฏิเสธคำขอมีอยู่ที่เซิร์ฟเวอร์ที่เดียว ถ้าไม่เขียนให้อ่านรู้เรื่อง ผู้ใช้จะเห็นแค่ "คำขอไม่สำเร็จ (400)"

**ทำไมไม่มี `UseHttpsRedirection`** — ตอน dev client วิ่ง http และการ redirect ไป https
กลาง CORS preflight จะล้มเหลวแบบที่ดูเหมือนเซิร์ฟเวอร์ไม่ขึ้น ตอน deploy จริงเอา TLS มาไว้ข้างหน้า

**ทำไม CORS ต้องระบุ origin ไม่ใช้ `*`** — เพราะเปิด `AllowCredentials` ไว้ให้ refresh cookie
วิ่งได้ และ spec ไม่ยอมให้ใช้ wildcard คู่กับ credentials

**ทำไม refresh token เป็น cookie ไม่ใช่ field ใน body** — `HttpOnly` ทำให้ JavaScript อ่านไม่ได้
บั๊ก XSS จึงขโมย token อายุ 7 วันไปไม่ได้ ส่วน access token อายุสั้นอยู่ใน memory ของ client

**ทำไม `[JsonIgnore(WhenWritingNull)]` ใส่บางฟิลด์เท่านั้น** — ฝั่ง TypeScript `field?:` (ไม่มีค่า)
กับ `field: X | null` (มีค่าเป็น null) คนละความหมาย ตัวหลังเช่น `Warehouse.position`
client เอาไปเทียบกับ `null` ตรง ๆ ถ้าตัดออกจาก JSON มันจะกลายเป็น `undefined` แล้วเข้าเงื่อนไขผิดข้าง

**ทำไมตั้ง `UnsafeRelaxedJsonEscaping`** — ไม่งั้นภาษาไทยทุกตัวออกมาเป็น `เ` อ่านไม่ออก
ทั้งใน network tab และใน log ซึ่งเป็นที่ที่ต้องเปิดดูตอนมีปัญหาพอดี ยังเป็น JSON ที่ถูกต้องเหมือนเดิม

---

## ยังไม่ได้ทำ

| เรื่อง | หมายเหตุ |
| --- | --- |
| **ฐานข้อมูล** | ยังเป็น in-memory · ดูหัวข้อถัดไป |
| **ตรวจรหัสผ่าน** | `AuthController` รับอีเมลแล้วออก token ให้เลย ยังไม่มีตาราง users |
| `/receipts` | เป็นของฝั่ง WMS (inbound) ไม่ใช่ TMS — จอนั้นยังวิ่งบน fixture เดิม จึงไม่ใส่ `receipts` ใน `VITE_API_LIVE` |
| ยิงออกไป MMX จริง | `SendManifest` บันทึกลง log แต่ยังไม่ได้ call ออกไปข้างนอก |
| รับ webhook จาก OMS | ตอนนี้ใช้ `POST /manifests/{id}/status` แทนไปก่อน |

### ขั้นต่อไป: ต่อฐานข้อมูล

ทำตามลำดับนี้ (ลอกรูปแบบจาก `KM_BE_Dev/OMS_KMTo/Database` ได้)

1. `dotnet add package Microsoft.EntityFrameworkCore.SqlServer` และ `...EntityFrameworkCore.Design`
2. สร้าง `Database/AppDbContext.cs` ที่มี `DbSet<Manifest>`, `DbSet<TransportPlan>` ฯลฯ
3. ใน `Program.cs` เปลี่ยน `AddSingleton<TmsStore>()` เป็น `AddScoped` แล้วฉีด `AppDbContext` เข้าไป
4. ใน `TmsStore` เปลี่ยน `List<T>` เป็น `DbSet<T>` และเอา `lock (_gate)` ออก
   (ฐานข้อมูลจัดการ concurrency ให้แทน — แต่ต้องห่อ "ย้ายใบสั่งส่ง" ด้วย transaction
   ไม่งั้นกติกา "อยู่ได้ที่เดียว" จะพังตอนมีคนใช้พร้อมกัน)
5. `dotnet ef migrations add Initial` แล้ว `dotnet ef database update`

**เมธอดในคลาสไม่ต้องย้ายที่** — กติกาอยู่ที่เดิม เปลี่ยนแค่ที่เก็บ

---

## ตั้งค่า

`appsettings.json`:

```jsonc
{
  "Jwt": { "Key": "..." },              // ⚠️ เปลี่ยนก่อน deploy — ตัวที่ให้มาเป็นค่า dev
  "Cors": { "Origins": ["http://localhost:5700"] }
}
```

ถ้าเปลี่ยน port ของ frontend ต้องเพิ่ม origin ตรงนี้ด้วย ไม่งั้น browser จะบล็อกทุก request
โดยขึ้น error ที่ดูเหมือนเซิร์ฟเวอร์ล่ม

---

## เอกสารอ้างอิง

- `docs/tms-sequence.md` ในโปรเจค frontend — ลำดับงานทั้งหมดและตารางว่า endpoint ไหนทำอะไร
- `src/features/*/api/*.mock.ts` ในโปรเจค frontend — โค้ดต้นทางที่ backend นี้แปลงมา
