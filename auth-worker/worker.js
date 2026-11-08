// VoiceCue sign-in helper. GitHub's login needs a server to swap the one-time
// code for a token (that step uses the app's secret), and this is that server.
// It stores nothing: the token goes straight back to the app in the URL fragment,
// which browsers never send to any server.
//
// Secrets (set with `wrangler secret put`): GITHUB_CLIENT_ID, GITHUB_CLIENT_SECRET

const ALLOWED_RETURNS = [
  "https://fullvaluedan.github.io/voicecue/",
  "http://localhost:4480/",
];

function allowedReturn(url) {
  return typeof url === "string" && ALLOWED_RETURNS.some((p) => url.startsWith(p));
}

function cookie(req, name) {
  const m = (req.headers.get("Cookie") || "").match(new RegExp("(?:^|; )" + name + "=([^;]*)"));
  return m ? decodeURIComponent(m[1]) : "";
}

export default {
  async fetch(req, env) {
    const url = new URL(req.url);

    if (url.pathname === "/login") {
      const ret = url.searchParams.get("return") || ALLOWED_RETURNS[0];
      if (!allowedReturn(ret)) return new Response("Bad return address", { status: 400 });
      const nonce = crypto.randomUUID();
      const gh = new URL("https://github.com/login/oauth/authorize");
      gh.searchParams.set("client_id", env.GITHUB_CLIENT_ID);
      gh.searchParams.set("scope", "gist");
      gh.searchParams.set("state", nonce);
      gh.searchParams.set("redirect_uri", url.origin + "/callback");
      return new Response(null, {
        status: 302,
        headers: {
          Location: gh.toString(),
          "Set-Cookie": "vc_auth=" + encodeURIComponent(JSON.stringify({ nonce, ret })) +
            "; Path=/; Max-Age=600; HttpOnly; Secure; SameSite=Lax",
        },
      });
    }

    if (url.pathname === "/callback") {
      let saved = {};
      try { saved = JSON.parse(cookie(req, "vc_auth") || "{}"); } catch (e) {}
      const ret = allowedReturn(saved.ret) ? saved.ret : ALLOWED_RETURNS[0];
      const back = (frag) => new Response(null, {
        status: 302,
        headers: { Location: ret.split("#")[0] + "#" + frag, "Set-Cookie": "vc_auth=; Path=/; Max-Age=0" },
      });
      const code = url.searchParams.get("code");
      if (!code || !saved.nonce || url.searchParams.get("state") !== saved.nonce) return back("gherr=state");
      const r = await fetch("https://github.com/login/oauth/access_token", {
        method: "POST",
        headers: { Accept: "application/json", "Content-Type": "application/json" },
        body: JSON.stringify({
          client_id: env.GITHUB_CLIENT_ID,
          client_secret: env.GITHUB_CLIENT_SECRET,
          code,
          redirect_uri: url.origin + "/callback",
        }),
      });
      const data = await r.json().catch(() => ({}));
      if (!data.access_token) return back("gherr=" + encodeURIComponent(data.error || "token"));
      return back("gh=" + encodeURIComponent(data.access_token));
    }

    return new Response("VoiceCue sign-in helper", { status: 200 });
  },
};
