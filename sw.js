/* DM Re:Vault offline service worker */
const CACHE="dmrevault-v100";
const CORE=["./","./index.html"];
self.addEventListener("install",e=>{
  e.waitUntil(caches.open(CACHE).then(c=>c.addAll(CORE)).then(()=>self.skipWaiting()));
});
self.addEventListener("activate",e=>{
  e.waitUntil(
    caches.keys().then(ks=>Promise.all(ks.filter(k=>k!==CACHE).map(k=>caches.delete(k))))
      .then(()=>self.clients.claim())
  );
});
self.addEventListener("fetch",e=>{
  const url=new URL(e.request.url);
  if(e.request.method!=="GET"||url.origin!==location.origin)return;
  // ネット優先→失敗（機内モード）ならキャッシュ。成功時はキャッシュ更新
  e.respondWith(
    fetch(e.request).then(res=>{
      const copy=res.clone();
      caches.open(CACHE).then(c=>c.put(e.request,copy)).catch(()=>{});
      return res;
    }).catch(()=>caches.match(e.request,{ignoreSearch:true}).then(r=>r||caches.match("./index.html")))
  );
});
