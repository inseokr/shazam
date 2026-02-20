/**
 * BlogGo OTP Worker
 *
 * Endpoints:
 *   POST /send-otp   { "email": "user@example.com" }
 *   POST /verify-otp { "email": "user@example.com", "code": "123456" }
 *
 * Environment bindings (set via Cloudflare dashboard or wrangler secret):
 *   RESEND_API_KEY  — your Resend API key
 *   OTP_KV          — KV namespace binding (see wrangler.toml)
 */

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type",
};

const OTP_TTL_SECONDS = 300; // 5 minutes

// ─── Entry Point ──────────────────────────────────────────────────────────────

export default {
  async fetch(request, env) {
    // Handle CORS preflight
    if (request.method === "OPTIONS") {
      return new Response(null, { headers: CORS_HEADERS });
    }

    const url = new URL(request.url);

    if (request.method === "POST" && url.pathname === "/send-otp") {
      return handleSendOTP(request, env);
    }

    if (request.method === "POST" && url.pathname === "/verify-otp") {
      return handleVerifyOTP(request, env);
    }

    return jsonResponse({ error: "Not found" }, 404);
  },
};

// ─── Send OTP ─────────────────────────────────────────────────────────────────

async function handleSendOTP(request, env) {
  let body;
  try {
    body = await request.json();
  } catch {
    return jsonResponse({ error: "Invalid JSON body." }, 400);
  }

  const email = (body?.email ?? "").trim().toLowerCase();
  if (!isValidEmail(email)) {
    return jsonResponse({ error: "Invalid email address." }, 400);
  }

  // Generate 6-digit OTP
  const otp = String(Math.floor(100000 + Math.random() * 900000));

  // Store in KV with 5-min TTL
  await env.OTP_KV.put(kvKey(email), otp, { expirationTtl: OTP_TTL_SECONDS });

  // Send email via Resend
  const emailResult = await sendResendEmail(env.RESEND_API_KEY, email, otp);
  if (!emailResult.ok) {
    const detail = await emailResult.text();
    console.error("Resend error:", detail);
    return jsonResponse({ error: "Failed to send email. Please try again." }, 502);
  }

  return jsonResponse({ success: true });
}

// ─── Verify OTP ───────────────────────────────────────────────────────────────

async function handleVerifyOTP(request, env) {
  let body;
  try {
    body = await request.json();
  } catch {
    return jsonResponse({ error: "Invalid JSON body." }, 400);
  }

  const email = (body?.email ?? "").trim().toLowerCase();
  const code  = (body?.code  ?? "").trim();

  if (!isValidEmail(email) || !code) {
    return jsonResponse({ error: "Missing email or code." }, 400);
  }

  const stored = await env.OTP_KV.get(kvKey(email));

  if (!stored) {
    // Either expired or never sent
    return jsonResponse({ error: "Code expired or not found. Please request a new code.", expired: true }, 401);
  }

  if (stored !== code) {
    return jsonResponse({ error: "Incorrect code. Please try again.", expired: false }, 401);
  }

  // Invalidate the code immediately (one-time use)
  await env.OTP_KV.delete(kvKey(email));

  return jsonResponse({ success: true });
}

// ─── Resend API ───────────────────────────────────────────────────────────────

async function sendResendEmail(apiKey, toEmail, otp) {
  const html = buildEmailHTML(otp);

  return fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${apiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      from: "BlogGo <bloggo@linkedspaces.com>",
      to: [toEmail],
      subject: "Your BlogGo sign-in code",
      html,
    }),
  });
}

// ─── Email Template ───────────────────────────────────────────────────────────

function buildEmailHTML(otp) {
  return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>Your BlogGo sign-in code</title>
</head>
<body style="margin:0;padding:0;background:#f4f4f5;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;">
  <table width="100%" cellpadding="0" cellspacing="0" style="background:#f4f4f5;padding:40px 0;">
    <tr>
      <td align="center">
        <table width="480" cellpadding="0" cellspacing="0" style="background:#0b0f2a;border-radius:16px;overflow:hidden;max-width:480px;width:100%;">
          <!-- Header -->
          <tr>
            <td style="padding:36px 40px 24px;text-align:center;">
              <p style="margin:0;font-size:28px;font-weight:700;color:#ffffff;letter-spacing:-0.5px;">BlogGo</p>
              <p style="margin:8px 0 0;font-size:14px;color:rgba(255,255,255,0.5);">Your travel blog companion</p>
            </td>
          </tr>
          <!-- Body -->
          <tr>
            <td style="padding:0 40px 12px;">
              <p style="margin:0;font-size:16px;color:rgba(255,255,255,0.85);line-height:1.6;">
                Here's your sign-in code. It expires in <strong style="color:#ffffff;">5 minutes</strong>.
              </p>
            </td>
          </tr>
          <!-- OTP Block -->
          <tr>
            <td align="center" style="padding:20px 40px 28px;">
              <div style="background:rgba(255,255,255,0.08);border:1.5px solid rgba(255,255,255,0.18);border-radius:12px;padding:24px 40px;display:inline-block;">
                <p style="margin:0;font-size:42px;font-weight:700;letter-spacing:14px;color:#ffffff;font-variant-numeric:tabular-nums;">${otp}</p>
              </div>
            </td>
          </tr>
          <!-- Warning -->
          <tr>
            <td style="padding:0 40px 36px;">
              <p style="margin:0;font-size:13px;color:rgba(255,255,255,0.4);line-height:1.5;">
                If you didn't request this code, you can safely ignore this email. Someone may have typed your email by mistake.
              </p>
            </td>
          </tr>
          <!-- Footer -->
          <tr>
            <td style="background:rgba(0,0,0,0.3);padding:20px 40px;border-top:1px solid rgba(255,255,255,0.06);">
              <p style="margin:0;font-size:12px;color:rgba(255,255,255,0.3);text-align:center;">
                Sent by BlogGo · bloggo@linkedspaces.com
              </p>
            </td>
          </tr>
        </table>
      </td>
    </tr>
  </table>
</body>
</html>`;
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

function kvKey(email) {
  return `otp:${email}`;
}

function isValidEmail(email) {
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email);
}

function jsonResponse(data, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
  });
}
