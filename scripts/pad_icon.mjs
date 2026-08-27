import sharp from 'sharp';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const src  = path.join(__dirname, '../assets/icon/icon.chatlive.1.png');

// ── 1. نسخة Adaptive Foreground ────────────────────────────────────────────
//  الـ safe zone = 66.7% من الـ foreground → نجعل الأيقونة تملأ الـ safe zone
//  بالكامل (100%) فتبدو بحجم طبيعي 100% على الشاشة
const CANVAS   = 1024;
const SCALE    = 0.72; // أيقونة تملأ ~108% من الـ safe zone → يبدو حجم طبيعي
const ICON_W   = Math.round(CANVAS * SCALE);
const PADDING  = Math.round((CANVAS - ICON_W) / 2);

const resized = await sharp(src)
  .resize(ICON_W, ICON_W, { fit: 'cover' })
  .toBuffer();

await sharp({
  create: { width: CANVAS, height: CANVAS, channels: 3,
            background: { r: 255, g: 255, b: 255 } },
})
  .composite([{ input: resized, left: PADDING, top: PADDING }])
  .png()
  .toFile(path.join(__dirname, '../assets/icon/icon.chatlive.1.padded.png'));

console.log(`✓ Adaptive foreground: ${ICON_W}px icon on ${CANVAS}px canvas (${PADDING}px padding)`);

// ── 2. نسخة Legacy (للأيقونة العادية و iOS) ────────────────────────────────
//  نُبقي على الحجم الكامل بدون padding إضافي — الزوايا المدورة المدمجة
//  بالأيقونة كافية
console.log('✓ Legacy: using original icon.chatlive.1.png as-is');
