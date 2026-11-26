#!/bin/sh
# Render the shared card around $BODY, into $GITHUB_OUTPUT.
#
# Everything comes in through the environment because the caller's values are
# already evaluated `${{ }}` expressions: HTML is not a shell argument list,
# and a card with an apostrophe in it should not need quoting rules.
#
# The markup is deliberately at column 0.  It is a document, not script, and
# indenting it to match the `{ } >> "$GITHUB_OUTPUT"` around it would put the
# heredoc terminator inside a YAML block scalar, where it cannot go.
set -eu

: "${GITHUB_OUTPUT:?GITHUB_OUTPUT is not set}"

{
  echo 'html<<P_CARD_EOF'
  cat <<EOF
<div style="margin:0;padding:24px 12px;background:#f5f6f8;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Helvetica,Arial,sans-serif;">
  <div style="max-width:560px;margin:0 auto;background:#ffffff;border:1px solid #e3e5e8;border-radius:10px;overflow:hidden;">
<div style="padding:20px 24px;background:${ACCENT};">
<div style="font-size:12px;letter-spacing:.08em;text-transform:uppercase;color:${KICKER_COLOR};">${KICKER}</div>
<div style="font-size:20px;font-weight:600;color:#ffffff;margin-top:4px;">${TITLE}</div>
</div>
<div style="padding:24px;">
EOF
  printf '%s\n' "$BODY"
  cat <<EOF
</div>
<div style="padding:14px 24px;background:#fafbfc;border-top:1px solid #eef0f2;font-size:12px;color:#8a9099;">
${FOOTER}
</div>
  </div>
</div>
EOF
  echo 'P_CARD_EOF'
} >> "$GITHUB_OUTPUT"
