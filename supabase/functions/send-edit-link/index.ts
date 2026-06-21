const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const { email, name, editUrl } = await req.json();

    if (!email || !editUrl) {
      return new Response(JSON.stringify({ error: "Missing email or editUrl" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const resendApiKey = Deno.env.get("RESEND_API_KEY");
    const from = Deno.env.get("RESEND_FROM");
    const replyTo = Deno.env.get("RESEND_REPLY_TO");

    if (!resendApiKey || !from) {
      throw new Error("Missing Resend configuration");
    }

    const response = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${resendApiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        from,
        to: [email],
        reply_to: replyTo,
        subject: "Dein Bearbeitungslink fuer den Z88 Kids Cup Standdienst",
        html: `
          <p>Hallo Mama/Papa von${name ? ` ${name}` : ""},</p>
          <p>hier kannst du deine ausgewaehlten Schichten bearbeiten:</p>
          <p><a href="${editUrl}">${editUrl}</a></p>
          <p>Bei Fragen antworte bitte auf diese E-Mail. Deine Antwort geht an ${replyTo}.</p>
          <p>Viele Gruesse<br>Z88 Standdienst</p>
        `,
        text: `Hallo${name ? ` ${name}` : ""},

hier kannst du deine ausgewaehlten Schichten bearbeiten:

${editUrl}

Bei Fragen antworte bitte auf diese E-Mail. Deine Antwort geht an ${replyTo}.

Viele Gruesse
Z88 Standdienst`,
      }),
    });

    const result = await response.json();

    if (!response.ok) {
      return new Response(JSON.stringify({ error: result }), {
        status: response.status,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    return new Response(JSON.stringify({ ok: true, result }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
