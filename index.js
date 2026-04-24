require('dotenv').config();
const express = require('express');
const cors = require('cors');
const { createClient } = require('@supabase/supabase-js');

// 1. تهيئة السيرفر
const app = express();
app.use(cors()); // السماح بالاتصال من الواجهات الأمامية
app.use(express.json()); // السماح للسيرفر بقراءة البيانات المرسلة بصيغة JSON

// 2. الاتصال بقاعدة البيانات (بصلاحيات الإدارة الكاملة)
const supabaseUrl = process.env.SUPABASE_URL;
const supabaseServiceKey = process.env.SUPABASE_SERVICE_KEY;
const supabaseAdmin = createClient(supabaseUrl, supabaseServiceKey);

// 3. المسارات (API Routes)

// أ. مسار فحص حالة السيرفر
app.get('/', (req, res) => {
    res.status(200).json({ message: 'Usaruna Engine is running securely.' });
});

// ب. مسار توثيق الأسر المنتجة (للإدارة فقط)
app.post('/api/verify-producer', async (req, res) => {
    try {
        const { producer_id } = req.body;

        if (!producer_id) {
            return res.status(400).json({ error: 'Producer ID is required.' });
        }

        // تحديث حالة التوثيق في قاعدة البيانات
        const { data, error } = await supabaseAdmin
            .from('producer_profiles')
            .update({ is_verified: true })
            .eq('user_id', producer_id)
            .select();

        if (error) throw error;

        res.status(200).json({ message: 'Producer verified successfully.', data });
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// ج. مسار بوابة الدفع (محاكاة عملية الدفع)
app.post('/api/checkout', async (req, res) => {
    try {
        const { order_id } = req.body;

        if (!order_id) {
            return res.status(400).json({ error: 'Order ID is required.' });
        }

        // هنا عادة نضع كود الاتصال الفعلي ببوابة "ميسر"
        // سنحاكي الآن أن الدفع تم بنجاح، ونحدث حالة الطلب
        
        const { data, error } = await supabaseAdmin
            .from('orders')
            .update({ payment_status: 'paid', status: 'accepted' })
            .eq('id', order_id)
            .select();

        if (error) throw error;

        res.status(200).json({ message: 'Payment processed and order accepted.', data });
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// 4. تشغيل المحرك
const PORT = process.env.PORT || 5000;
app.listen(PORT, () => {
    console.log(`🚀 Usaruna Backend is running on port ${PORT}`);
});