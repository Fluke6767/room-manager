const $=id=>document.getElementById(id);
const SUPABASE_URL="https://djoyoeliscasgpwzvfpb.supabase.co";
const SUPABASE_ANON_KEY="sb_publishable_WWWw0HNtBhgcIDRgEM6dXA_a-SQ4ia-";
if(!window.supabase){const n=$("setupNote");if(n)n.textContent="โหลดระบบเชื่อมต่อ Supabase ไม่สำเร็จ กรุณารีเฟรชหน้าเว็บ";throw new Error("Supabase JS failed to load")}
const sb=window.supabase.createClient(SUPABASE_URL,SUPABASE_ANON_KEY);
const roles={owner:"เจ้าของเว็บ",developer:"ผู้ช่วยพัฒนา",leader:"หัวหน้าห้อง",deputy:"รองหัวหน้า",student:"นักเรียน"};
const nav=[["home","⌂","ภาพรวม"],["tasks","✓","งานเวร"],["reports","⚑","รายงาน"],["money","฿","เงินห้อง"],["members","◎","รายชื่อ"],["chat","☁","แชท"],["profile","◉","โปรไฟล์"],["settings","⚙","ตั้งค่า"]];
let S={user:null,p:null,members:[],tasks:[],reports:[],payments:[],messages:[],view:"home",theme:localStorage.roomTheme||"blue",mode:"login"};
const esc=x=>String(x??"").replace(/[&<>"']/g,c=>({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#39;"}[c]));
const leader=()=>["owner","developer","leader","deputy"].includes(S.p?.role);
const owner=()=>["owner","developer"].includes(S.p?.role);
function toast(message){const el=$("toast");if(!el)return;el.textContent=message;el.classList.remove("hidden");clearTimeout(window.tt);window.tt=setTimeout(()=>el.classList.add("hidden"),2800)}
function avatar(p){if(p?.avatar_url)return `<img class="avatar-image" src="${esc(p.avatar_url)}" alt="${esc(p.display_name||"โปรไฟล์")}" loading="lazy" decoding="async">`;const initials=(p?.display_name||"?").trim().split(/\s+/).map(x=>x[0]||"").join("").slice(0,2).toUpperCase();return `<span class="avatar-initials">${esc(initials||"?")}</span>`}
function date(x){if(!x)return "-";const d=new Date(x);if(Number.isNaN(d.getTime()))return "-";return d.toLocaleString("th-TH",{dateStyle:"short",timeStyle:"short"})}
function theme(){document.documentElement.dataset.theme=S.theme;localStorage.roomTheme=S.theme}
function go(view){S.view=view;render()}
function modal(title,body){$("mt").textContent=title;$("mb").innerHTML=body;$("modal").classList.remove("hidden")}
function closeModal(){$("modal").classList.add("hidden")}
