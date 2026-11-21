import { useCallback, useEffect, useState } from 'react'
import { supabase } from './lib/supabase'
import { Clock3, MessageCircle, Plus, RefreshCw, Send, Shield, X } from 'lucide-react'
import './support-center.css'

type Report = { id:string; subject:string; category:string; description:string; status:string; priority:string; created_at:string; reporter_id:string }
type Message = { id:string; sender_id:string; message:string; is_internal:boolean; created_at:string }

const statusNames:Record<string,string>={open:'مفتوح',in_progress:'قيد المعالجة',waiting_user:'بانتظار المستخدم',resolved:'تم الحل',closed:'مغلق'}
const categories=[['general','استفسار عام'],['order','طلب أو توصيل'],['product','منتج'],['store','متجر أو تاجر'],['courier','مندوب توصيل'],['payment','الدفع'],['technical','مشكلة تقنية'],['abuse','بلاغ أو إساءة']]

export default function SupportCenter({onClose}:{onClose:()=>void}){
 const [userId,setUserId]=useState('')
 const [isAdmin,setIsAdmin]=useState(false)
 const [reports,setReports]=useState<Report[]>([])
 const [active,setActive]=useState<Report|null>(null)
 const [messages,setMessages]=useState<Message[]>([])
 const [subject,setSubject]=useState('')
 const [category,setCategory]=useState('general')
 const [description,setDescription]=useState('')
 const [reply,setReply]=useState('')
 const [internal,setInternal]=useState(false)
 const [status,setStatus]=useState('open')
 const [busy,setBusy]=useState(false)
 const [creating,setCreating]=useState(false)
 const [error,setError]=useState('')
 const loadReports=useCallback(async()=>{
  if(!supabase)return
  const {data,error}=await supabase.from('support_reports').select('id,subject,category,description,status,priority,created_at,reporter_id').order('updated_at',{ascending:false}).limit(100)
  if(error){setError('تعذر تحميل البلاغات. تحقق من تسجيل الدخول والصلاحيات.');return}
  setReports((data||[]) as Report[])
 },[])
 const loadMessages=useCallback(async(reportId:string)=>{
  if(!supabase)return
  const {data,error}=await supabase.from('support_report_messages').select('id,sender_id,message,is_internal,created_at').eq('report_id',reportId).order('created_at')
  if(error){setError('تعذر تحميل المحادثة.');return}
  setMessages((data||[]) as Message[])
 },[])
 useEffect(()=>{
  let channel:any
  const start=async()=>{
   if(!supabase)return
   const {data:{user}}=await supabase.auth.getUser()
   if(!user){setError('سجّل الدخول أولاً لاستخدام مركز الدعم.');return}
   setUserId(user.id)
   const {data:profile}=await supabase.from('profiles').select('role').eq('id',user.id).maybeSingle()
   setIsAdmin(profile?.role==='admin')
   await loadReports()
   channel=supabase.channel('support-center-'+user.id)
    .on('postgres_changes',{event:'*',schema:'public',table:'support_reports'},()=>void loadReports())
    .on('postgres_changes',{event:'*',schema:'public',table:'support_report_messages'},()=>{if(active)void loadMessages(active.id)})
    .subscribe()
  }
  void start()
  return()=>{if(channel&&supabase)supabase.removeChannel(channel)}
 },[loadReports,loadMessages,active?.id])
 const openReport=async(report:Report)=>{setActive(report);setStatus(report.status);setError('');await loadMessages(report.id)}
 const createReport=async()=>{
  if(!supabase||!userId)return
  setBusy(true);setError('')
  const {data,error}=await supabase.from('support_reports').insert({reporter_id:userId,subject,category,description}).select('id,subject,category,description,status,priority,created_at,reporter_id').single()
  if(error){setError('تعذر إرسال البلاغ: '+error.message);setBusy(false);return}
  setSubject('');setDescription('');setCreating(false);await loadReports();if(data)await openReport(data as Report);setBusy(false)
 }
 const sendReply=async()=>{
  if(!supabase||!active||!userId||!reply.trim())return
  setBusy(true);setError('')
  const {error}=await supabase.from('support_report_messages').insert({report_id:active.id,sender_id:userId,message:reply.trim(),is_internal:isAdmin&&internal})
  if(error)setError('تعذر إرسال الرد: '+error.message)
  else{setReply('');setInternal(false);await loadMessages(active.id);await loadReports()}
  setBusy(false)
 }
 const updateStatus=async(next:string)=>{
  if(!supabase||!active||!isAdmin)return
  setBusy(true);const {error}=await supabase.from('support_reports').update({status:next,resolved_at:['resolved','closed'].includes(next)?new Date().toISOString():null}).eq('id',active.id)
  if(error)setError('تعذر تحديث الحالة: '+error.message)
  else{setStatus(next);setActive({...active,status:next});await loadReports()}
  setBusy(false)
 }
 return <div className="support-overlay" dir="rtl"><section className="support-shell"><header className="support-head"><div><span>TOOR BE · خدمة العملاء</span><h2>مركز الدعم والبلاغات</h2></div><button onClick={onClose} aria-label="إغلاق"><X/></button></header>
  <div className="support-layout"><aside className="support-list"><div className="support-list-head"><b>{isAdmin?'جميع البلاغات':'بلاغاتي'}</b><button onClick={()=>void loadReports()} title="تحديث"><RefreshCw size={17}/></button></div>
   {!isAdmin&&<button className="support-new" onClick={()=>{setCreating(true);setActive(null);setError('')}}><Plus size={17}/> إرسال بلاغ جديد</button>}
   {reports.map(r=><button key={r.id} className={'support-report-item '+(active?.id===r.id?'active':'')} onClick={()=>void openReport(r)}><b>{r.subject}</b><span>{statusNames[r.status]||r.status} · {new Date(r.created_at).toLocaleDateString('ar-JO')}</span></button>)}
   {!reports.length&&<p className="support-empty">لا توجد بلاغات حتى الآن.</p>}
  </aside>
  <main className="support-conversation">
   {creating?<div className="support-form"><h3>إرسال بلاغ جديد</h3><label>عنوان البلاغ<input value={subject} onChange={e=>setSubject(e.target.value)} maxLength={160} placeholder="اكتب عنواناً واضحاً"/></label><label>التصنيف<select value={category} onChange={e=>setCategory(e.target.value)}>{categories.map(([v,n])=><option key={v} value={v}>{n}</option>)}</select></label><label>التفاصيل<textarea value={description} onChange={e=>setDescription(e.target.value)} rows={5} maxLength={5000} placeholder="اشرح المشكلة بالتفصيل حتى نتمكن من مساعدتك"/></label><button className="support-primary" disabled={busy||subject.trim().length<4||description.trim().length<10} onClick={()=>void createReport()}>{busy?'جارٍ الإرسال...':'إرسال البلاغ'}</button></div>
   :active?<><div className="support-conversation-head"><div><h3>{active.subject}</h3><span><Clock3 size={14}/> {statusNames[status]||status} · {new Date(active.created_at).toLocaleString('ar-JO')}</span></div>{isAdmin&&<select value={status} disabled={busy} onChange={e=>void updateStatus(e.target.value)}>{Object.entries(statusNames).map(([v,n])=><option key={v} value={v}>{n}</option>)}</select>}</div>
    <article className="support-original"><b>تفاصيل البلاغ</b><p>{active.description}</p></article>
    <div className="support-messages">{messages.map(m=><article key={m.id} className={'support-message '+(m.sender_id===userId?'mine':'')+(m.is_internal?' internal':'')}><div>{m.is_internal&&<Shield size={13}/>}<p>{m.message}</p></div><small>{new Date(m.created_at).toLocaleString('ar-JO')}{m.is_internal?' · ملاحظة داخلية':''}</small></article>)}{!messages.length&&<p className="support-empty">لا توجد ردود بعد. يمكنك كتابة أول رد.</p>}</div>
    {status!=='closed'&&status!=='resolved'&&<div className="support-reply"><textarea rows={2} value={reply} onChange={e=>setReply(e.target.value)} placeholder={isAdmin?'اكتب رد الإدارة...':'اكتب ردك هنا...'}/>{isAdmin&&<label className="support-internal"><input type="checkbox" checked={internal} onChange={e=>setInternal(e.target.checked)}/> ملاحظة داخلية للإدارة فقط</label>}<button className="support-primary" disabled={busy||!reply.trim()} onClick={()=>void sendReply()}><Send size={16}/> إرسال</button></div>}
   </>:<div className="support-welcome"><MessageCircle size={36}/><h3>كيف يمكننا مساعدتك؟</h3><p>اختر بلاغاً من القائمة أو أنشئ بلاغاً جديداً ليتابع فريق TOOR BE طلبك.</p></div>}
   {error&&<p className="support-error">{error}</p>}
  </main></div></section></div>
}
