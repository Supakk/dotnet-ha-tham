# Mammod TMS — Backend
เขียนด้วย ASP.NET Core (net8.0) ตาม stack 

ตอนนี้ข้อมูลเก็บ **ในหน่วยความจำ** ยังไม่มีฐานข้อมูล — รีสตาร์ทแล้วข้อมูลกลับไปเป็นค่าตั้งต้น
กติกาทางธุรกิจทั้งหมดของจริงอยู่ครบแล้ว ที่ขาดคือที่เก็บถาวร

> ### ⚠️ โปรเจคนี้ไว้ฝึก ยังไม่พร้อมขึ้นใช้งานจริง
>
> **ยังไม่มีการตรวจรหัสผ่าน** — `/auth/login` รับอีเมลแล้วออก token ให้เลย ใครก็ตามที่
> เข้าถึงเซิร์ฟเวอร์ได้ ขอ token เป็น `admin` ได้ทันที ถ้าเอาขึ้นอินเทอร์เน็ตตอนนี้
> เท่ากับเปิดให้ทุกคนเป็นผู้ดูแลระบบ
>
> **ข้อมูลในนี้เป็นข้อมูลสมมติทั้งหมด** — ชื่อบริษัท เลขผู้เสียภาษี เบอร์โทร ทะเบียนรถ
> ยกมาจาก fixture ของ frontend ไม่ใช่ข้อมูลลูกค้าจริง **ห้ามเอาข้อมูลลูกค้าจริงมาใส่
> ใน `Data/Seed.cs`** เพราะไฟล์นั้นถูก commit ขึ้น repo สาธารณะ
>
> ใช้บนเครื่องตัวเองหรือในวง LAN ที่ไว้ใจได้เท่านั้น อ่านหัวข้อ
> [ก่อนเอาขึ้นเซิร์ฟเวอร์จริง](#ก่อนเอาขึ้นเซิร์ฟเวอร์จริง) ก่อน deploy

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

```ini
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
| **ตรวจรหัสผ่าน** | `AuthController` รับอีเมลแล้วออก token ให้เลย ยังไม่มีตาราง users — ดู [checklist](#ก่อนเอาขึ้นเซิร์ฟเวอร์จริง) |
| **จำกัดสิทธิ์ตาม role** | มี token = ทำได้ทุกอย่าง ยังไม่ได้แยกว่า `viewer` ทำอะไรได้บ้าง |
| `/receipts` | เป็นของฝั่ง WMS (inbound) ไม่ใช่ TMS — จอนั้นยังวิ่งบน fixture เดิม จึงไม่ใส่ `receipts` ใน `VITE_API_LIVE` |
| ยิงออกไป MMX จริง | `SendManifest` บันทึกลง log แต่ยังไม่ได้ call ออกไปข้างนอก |
| รับ webhook จาก OMS | ตอนนี้ใช้ `POST /manifests/{id}/status` แทนไปก่อน |

### ขั้นต่อไป: ต่อฐานข้อมูล

โครงสร้างฐานจริงกับส่วนที่ต้องแก้ก่อนต่อได้ อยู่ใน [`docs/data-model/`](docs/data-model/) —
อ่าน [README ของโฟลเดอร์นั้น](docs/data-model/README.md) ก่อนเริ่ม โดยเฉพาะหัวข้อ 2
เพราะตารางส่วนใหญ่ในฐานจริง**ยังไม่มี PRIMARY KEY** ซึ่ง EF Core จะ map เป็น
keyless entity ที่เขียนกลับไม่ได้ ต้องรัน `02-alter-existing.sql` ส่วน A ก่อน

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

`appsettings.json` มีเฉพาะค่าที่ไม่เป็นความลับ:

```jsonc
{
  "Jwt":  { "Issuer": "...", "Audience": "..." },   // ไม่มี Key — ดูข้างล่าง
  "Cors": { "Origins": ["http://localhost:5700"] },
  "Auth": { "RequireAuthentication": false }        // ตอน dev เท่านั้น
}
```

ถ้าเปลี่ยน port ของ frontend ต้องเพิ่ม origin ตรงนี้ด้วย ไม่งั้น browser จะบล็อกทุก request
โดยขึ้น error ที่ดูเหมือนเซิร์ฟเวอร์ล่ม

### กุญแจเซ็น JWT

กุญแจตัวนี้เป็นสิ่งเดียวที่แยก "token ที่เซิร์ฟเวอร์ออกให้" ออกจาก "token ที่ใครก็ปลอมได้"
ใครอ่านมันได้ก็เซ็น token เป็น admin เองได้ทันที **จึงไม่มีอยู่ในไฟล์ใด ๆ ที่ commit**

| ตอนไหน | มาจากไหน |
| --- | --- |
| dev | สร้างสุ่มอัตโนมัติครั้งแรกที่รัน เก็บไว้ที่ `.secrets/jwt-key` ซึ่ง gitignore ไว้แล้ว |
| production | ต้องตั้ง env var `Jwt__Key` (ขีดล่าง **สอง** อัน) เอง **ถ้าไม่ตั้ง เซิร์ฟเวอร์จะไม่ยอมขึ้นเลย** |

สุ่มค่าใหม่:

```bash
node -e "console.log(require('crypto').randomBytes(48).toString('base64'))"
```

ที่เลือกให้ล้มตั้งแต่ตอนเปิดเครื่อง แทนที่จะใส่ค่า default ไว้ให้ เพราะค่า default ที่อยู่ใน
โค้ดสาธารณะไม่ต่างจากไม่มีกุญแจเลย และความผิดพลาดที่ดังตอน deploy ดีกว่าความผิดพลาดที่เงียบ

---

## ก่อนเอาขึ้นเซิร์ฟเวอร์จริง

ตอนนี้รันได้แค่บนเครื่องตัวเอง ถ้าจะเอาขึ้นที่ที่คนอื่นเข้าถึงได้ ต้องทำครบทุกข้อนี้ก่อน

- [ ] **ตรวจรหัสผ่านจริง** — ทำตาราง users แล้วเก็บรหัสด้วย BCrypt (`BCrypt.Net-Next`
      ตัวเดียวกับที่ `KM_BE_Dev` ใช้) **ห้ามเก็บรหัสผ่านเป็นข้อความธรรมดาเด็ดขาด**
      แก้ที่ `AuthController.Accounts` ที่เดียว
- [ ] **ตั้ง `Jwt__Key`** เป็นค่าสุ่มยาว ๆ และอย่าใช้ค่าเดียวกับเครื่อง dev
- [ ] **เปิด HTTPS** แล้วเอา TLS มาไว้ข้างหน้า — ตอนนี้ token วิ่งเป็น plain text
      พอเป็น https แล้ว refresh cookie จะเปลี่ยนเป็น `Secure` + `SameSite=None` อัตโนมัติ
- [ ] **แก้ `Cors:Origins`** ให้เป็นโดเมนจริงของ frontend อย่าใส่ `*` (ใส่ไม่ได้อยู่แล้ว
      เพราะเปิด credentials ไว้ แต่อย่าพยายามหาทางเลี่ยง)
- [ ] **ตรวจว่า `ASPNETCORE_ENVIRONMENT` ไม่ใช่ `Development`** — ไม่งั้น Swagger จะเปิด
      โล่งและ endpoint จะไม่บังคับ token
- [ ] **จำกัดสิทธิ์ตาม role** — ตอนนี้มี token คือทำได้ทุกอย่าง คนที่ role `viewer`
      ก็ยกเลิกใบปิดบรรทุกได้ ต้องเติม `[Authorize(Roles = "...")]` ตามจอที่ frontend กั้นไว้
- [ ] **เปลี่ยนที่เก็บเป็นฐานข้อมูล** และเก็บ connection string ใน env var ไม่ใช่ในไฟล์
- [ ] **ใส่ rate limit ที่ `/auth/login`** ไม่งั้นเดารหัสผ่านได้ไม่จำกัดรอบ

### กติกาสำหรับ repo สาธารณะ

- อะไรที่ commit ไปแล้ว **ถือว่าหลุดถาวร** ต่อให้ลบทีหลังก็ยังอยู่ใน git history
  ถ้าเผลอ commit key จริงลงไป วิธีแก้คือ**ไปเพิกถอน key ตัวนั้น** ไม่ใช่ลบ commit
- ค่าที่หน้าตาเหมือน secret ในโค้ดนี้ (`EXAMPLE-NOT-A-REAL-SECRET-…`) ตั้งชื่อให้อ่านแล้ว
  รู้ทันทีว่าปลอม — ถ้าจะเพิ่มค่าสมมติใหม่ ตั้งชื่อแนวเดียวกัน
- อย่าใส่ข้อมูลลูกค้าจริงลง `Data/Seed.cs` หรือ `Mammod_BackEnd.http`

---

## เอกสารอ้างอิง

- [`docs/data-model/`](docs/data-model/) — โครงสร้างฐานจริง (`MMPRD`) · ตารางที่ต้องเพิ่ม ·
  สคริปต์แก้ตารางเดิม · ไดอะแกรม ER สองฝั่ง (ขนส่ง / คลัง)
- `docs/tms-sequence.md` ในโปรเจค frontend — ลำดับงานทั้งหมดและตารางว่า endpoint ไหนทำอะไร
- `src/features/*/api/*.mock.ts` ในโปรเจค frontend — โค้ดต้นทางที่ backend นี้แปลงมา
