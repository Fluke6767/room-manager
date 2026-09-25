async function sendMessage(e){e.preventDefault();const input=$("chatInput"),v=input.value.trim();if(!v)return;const r=await sb.from("messages").insert({room_id:S.p.room_id,sender_id:S.user.id,body:v});if(r.error)toast(r.error.message);else{input.value="";loadAll()}}
function setTheme(x){S.theme=x;theme();render()}
async function logout(){await sb.auth.signOut();location.reload()}
