import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.38.4"
import { create, getNumericDate } from "https://deno.land/x/djwt@v2.8/mod.ts"

serve(async (req) => {
    try {
        console.log("🚀 Streak Reminder function started");

        const supabase = createClient(
            Deno.env.get('SUPABASE_URL') ?? '',
            Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
        )

        const today = new Date().toISOString().split('T')[0]
        console.log(`📅 Checking for date: ${today}`);

        // 1. Ambil List User yang BELUM tilawah hari ini
        const { data: incompleteGoals, error: goalError } = await supabase
            .from('daily_goal_progress')
            .select('user_id')
            .eq('goal_date', today)
            .eq('is_completed', false)

        if (goalError) {
            console.error("❌ Error fetching daily_goal_progress:", goalError);
            throw goalError;
        }

        if (!incompleteGoals || incompleteGoals.length === 0) {
            console.log("✅ No users with incomplete goals today.");
            return new Response(JSON.stringify({ message: "No reminders needed" }), {
                headers: { "Content-Type": "application/json" }
            });
        }

        const userIds = incompleteGoals.map((g: any) => g.user_id);
        console.log(`📝 Found ${userIds.length} users with incomplete goals.`);

        // 2. Ambil FCM tokens untuk user-user tersebut (notification_enabled = true atau NULL)
        const { data: tokens, error: tokenError } = await supabase
            .from('user_fcm_tokens')
            .select('fcm_token, language_code, user_id, notification_enabled')
            .in('user_id', userIds)
            .neq('notification_enabled', false)

        if (tokenError) {
            console.error("❌ Error fetching FCM tokens:", tokenError);
            throw tokenError;
        }

        if (!tokens || tokens.length === 0) {
            console.log("⚠️ Found users but no FCM tokens registered.");
            return new Response(JSON.stringify({ message: "No tokens found" }), {
                headers: { "Content-Type": "application/json" }
            });
        }

        console.log(`📱 Found ${tokens.length} FCM tokens to notify.`);

        // 3. Ambil Access Token Firebase (Deno-native)
        const accessToken = await getGoogleAccessToken();

        // 4. Kirim Notifikasi
        let successCount = 0;
        for (const tokenItem of tokens) {
            const lang = tokenItem.language_code || 'id';

            let title = "Streak Hampir Putus! 🚨";
            let body = "Jangan lupa tilawah hari ini ya agar targetmu tercapai. ✨";

            if (lang === 'en') {
                title = "Streak Falling Behind! 🚨";
                body = "Don't forget to recite today to keep your goal on track. ✨";
            } else if (lang === 'ar') {
                title = "تذكير بالتلاوة! 🚨";
                body = "لا تنسَ وردك القرآني اليوم للمحافظة على سلسلتك. ✨";
            }

            const success = await sendPushNotification(
                accessToken,
                tokenItem.fcm_token,
                title,
                body
            );
            if (success) successCount++;
        }

        console.log(`✅ Finished. Sent ${successCount} notifications.`);
        return new Response(JSON.stringify({ message: "Success", sent: successCount }), {
            headers: { "Content-Type": "application/json" }
        });

    } catch (err: any) {
        console.error("🔥 Fatal error in Edge Function:", err);
        return new Response(JSON.stringify({ error: err.message || String(err) }), {
            status: 500,
            headers: { "Content-Type": "application/json" }
        });
    }
})

// Deno-native JWT signing for Google OAuth2
async function getGoogleAccessToken(): Promise<string> {
    const secret = Deno.env.get('FIREBASE_SERVICE_ACCOUNT');
    if (!secret) throw new Error("FIREBASE_SERVICE_ACCOUNT secret is missing");

    const serviceAccount = JSON.parse(secret);
    const privateKeyPem = serviceAccount.private_key;

    // Import the private key
    const pemHeader = "-----BEGIN PRIVATE KEY-----";
    const pemFooter = "-----END PRIVATE KEY-----";
    const pemContents = privateKeyPem.replace(pemHeader, "").replace(pemFooter, "").replace(/\s/g, "");
    const binaryDer = Uint8Array.from(atob(pemContents), c => c.charCodeAt(0));

    const cryptoKey = await crypto.subtle.importKey(
        "pkcs8",
        binaryDer,
        { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
        false,
        ["sign"]
    );

    const now = Math.floor(Date.now() / 1000);
    const jwt = await create(
        { alg: "RS256", typ: "JWT" },
        {
            iss: serviceAccount.client_email,
            sub: serviceAccount.client_email,
            aud: "https://oauth2.googleapis.com/token",
            iat: now,
            exp: now + 3600,
            scope: "https://www.googleapis.com/auth/cloud-platform"
        },
        cryptoKey
    );

    // Exchange JWT for access token
    const tokenRes = await fetch("https://oauth2.googleapis.com/token", {
        method: "POST",
        headers: { "Content-Type": "application/x-www-form-urlencoded" },
        body: `grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=${jwt}`
    });

    const tokenData = await tokenRes.json();
    if (!tokenData.access_token) {
        console.error("❌ Failed to get access token:", tokenData);
        throw new Error("Failed to get Google access token");
    }

    return tokenData.access_token;
}

async function sendPushNotification(accessToken: string, fcmToken: string, title: string, body: string) {
    try {
        const serviceAccount = JSON.parse(Deno.env.get('FIREBASE_SERVICE_ACCOUNT') ?? '{}');
        const projectId = serviceAccount.project_id;
        const url = `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`;

        const message = {
            message: {
                token: fcmToken,
                notification: { title, body },
                android: {
                    notification: { icon: "ic_launcher", color: "#000000" }
                }
            }
        };

        const res = await fetch(url, {
            method: "POST",
            headers: {
                "Authorization": `Bearer ${accessToken}`,
                "Content-Type": "application/json",
            },
            body: JSON.stringify(message),
        });

        if (res.ok) return true;

        const errData = await res.json();
        console.error(`❌ FCM Send Error:`, errData);
        return false;
    } catch (e) {
        console.error("❌ Network error sending FCM:", e);
        return false;
    }
}
