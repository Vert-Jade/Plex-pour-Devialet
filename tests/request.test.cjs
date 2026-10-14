const {test}=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');const vm=require('node:vm');
const source=fs.readFileSync('app/Request.qml','utf8');
const functions=source.slice(source.indexOf('    function cancel'),source.indexOf('    Timer {'));
function setup(){
 const s={busy:false,xhr:null,generation:0,failure:null,deadline:{start(){},stop(){}},JSON};
 class XHR {
  static DONE=4;
  constructor(){s.last=this;this.headers={}}
  open(method,url){this.method=method;this.url=url}
  setRequestHeader(k,v){this.headers[k]=v}
  send(){}
  abort(){this.aborted=true}
  reply(status,text){this.status=status;this.responseText=text;this.readyState=4;this.onreadystatechange()}
 }
 s.XMLHttpRequest=XHR;vm.createContext(s);vm.runInContext(functions,s);return s;
}
test('switching a library cancels old request and ignores late responses',()=>{
 const s=setup();let results=[];s.send('GET','https://one',{},v=>results.push(v),()=>{});const old=s.last;
 s.send('GET','https://two',{},v=>results.push(v),()=>{});old.reply(200,'{"old":true}');s.last.reply(200,'{"current":true}');
 assert.equal(old.aborted,true);assert.equal(results.length,1);assert.equal(results[0].current,true);assert.equal(s.busy,false);
});
test('malformed response and HTTP failures release loading state',()=>{
 for (const [status,body,expected] of [[200,'broken',-2],[401,'{}',401],[0,'',0]]){
  const s=setup();let failure=null;s.send('GET','https://server',{},()=>assert.fail(),e=>failure=e);s.last.reply(status,body);assert.equal(failure,expected);assert.equal(s.busy,false);
 }
});
test('canceling a request clears credentials and timeout callback references',()=>{
 const s=setup();s.send('GET','https://server',{'X-Plex-Token':'secret'},()=>{},()=>{});const old=s.last;s.cancel();assert.equal(s.xhr,null);assert.equal(s.failure,null);assert.equal(old.aborted,true);
});
