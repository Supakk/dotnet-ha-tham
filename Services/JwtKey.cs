using System.Security.Cryptography;

namespace Mammod.Services;

/// <summary>
/// หากุญแจที่ใช้เซ็น JWT — และตั้งใจไม่ให้มันอยู่ในไฟล์ที่ commit ได้
///
/// กุญแจนี้คือสิ่งเดียวที่กั้นระหว่าง "token ที่เซิร์ฟเวอร์ออกให้" กับ "token ที่ใครก็ได้
/// ปลอมขึ้นมาเอง" ใครที่อ่านมันได้ ก็ออก token เป็น admin ได้ทันทีโดยไม่ต้องรู้รหัสผ่าน
/// ดังนั้นการเขียนมันลง <c>appsettings.json</c> ใน repo สาธารณะ เท่ากับแจกสิทธิ์ admin
/// ให้ทุกคนที่กด clone
///
/// ลำดับการหา:
///   1. <c>Jwt:Key</c> จาก environment variable หรือ user-secrets — ใช้ตัวนี้ก่อนเสมอ
///   2. ตอน dev ถ้าไม่มี จะสุ่มขึ้นมาเก็บไว้ที่ <c>.secrets/jwt-key</c> ซึ่ง gitignore ไว้แล้ว
///      (เก็บเป็นไฟล์ ไม่ใช่สุ่มใหม่ทุกครั้ง เพราะไม่งั้นรีสตาร์ททีต้อง login ใหม่ที)
///   3. ตอน production ถ้าไม่มี ให้ **ล้มตั้งแต่ตอนเปิดเครื่อง** ดีกว่าขึ้นมาแล้วเซ็นด้วยค่า
///      default ที่ใครก็เดาได้ — ความผิดพลาดที่ดังตอน deploy ดีกว่าความผิดพลาดที่เงียบ
/// </summary>
public static class JwtKey
{
    private const string DevKeyPath = ".secrets/jwt-key";

    public static string Resolve(IConfiguration config, IWebHostEnvironment env)
    {
        var configured = config["Jwt:Key"];
        if (!string.IsNullOrWhiteSpace(configured)) return configured;

        if (!env.IsDevelopment())
        {
            throw new InvalidOperationException(
                "ไม่ได้ตั้งค่า Jwt:Key — ตั้งผ่าน environment variable ชื่อ Jwt__Key " +
                "(ขีดล่างสองอัน) ด้วยค่าสุ่มยาวอย่างน้อย 32 ตัวอักษร ห้ามใช้ค่าที่เขียนไว้ในโค้ด");
        }

        return DevKey(env);
    }

    /// <summary>
    /// กุญแจสำหรับเครื่องตัวเอง สร้างครั้งเดียวแล้วใช้ต่อ — และไม่มีวันขึ้น git
    /// เพราะโฟลเดอร์ <c>.secrets/</c> อยู่ใน <c>.gitignore</c>
    /// </summary>
    private static string DevKey(IWebHostEnvironment env)
    {
        var path = Path.Combine(env.ContentRootPath, DevKeyPath);
        if (File.Exists(path))
        {
            var existing = File.ReadAllText(path).Trim();
            if (existing.Length >= 32) return existing;
        }

        // 64 ไบต์จาก RandomNumberGenerator ไม่ใช่ Random: ตัวหลังคาดเดาได้ถ้ารู้เวลาที่สุ่ม
        var generated = Convert.ToBase64String(RandomNumberGenerator.GetBytes(64));
        Directory.CreateDirectory(Path.GetDirectoryName(path)!);
        File.WriteAllText(path, generated);
        Console.WriteLine($"[Jwt] สร้างกุญแจสำหรับ development ไว้ที่ {DevKeyPath} (ไฟล์นี้ไม่ขึ้น git)");
        return generated;
    }
}
