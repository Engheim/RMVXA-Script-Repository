(function($){if($.wpcom_proxy_request){return;}
var proxy,origin=window.location.protocol+'//'+window.location.hostname,proxyOrigin='https://public-api.wordpress.com',ready=false,supported=true,usingPM=false,structuredData=true,bufferedOps=[],deferreds={},check=function(event){structuredData='object'===typeof event.originalEvent.data;$(window).unbind('message',check);buildProxy();},buildProxy=function(){if(!usingPM){$(window).bind('message',receive);}else{pm.bind('proxy',function(e){receive(e);});}
proxy=document.createElement('iframe');proxy.src='https://public-api.wordpress.com/wp-admin/rest-proxy/#'+origin;proxy.style.display='none';$(proxy).bind('load',function(){var request;ready=true;while(request=bufferedOps.shift()){postRequest(request);}});$(document).ready(function(){$(document.body).append(proxy);});},receive=function(e){var event,data,deferred_id,deferred;if(!usingPM){event=e.originalEvent;if(event.origin!==proxyOrigin){return;}
data=structuredData?event.data:JSON.parse(event.data);}else{data=e;}
if(!data||typeof data.pop!='function'){return;}
deferred_id=data.pop();if('undefined'===typeof deferreds[deferred_id]){return;}
deferred=deferreds[deferred_id];delete deferreds[deferred_id];deferred.resolve.apply(deferred,data);},perform=function(){var request=buildRequest.apply(null,arguments);postRequest(request);return deferreds[request.callback].promise();},buffer=function(){var request=buildRequest.apply(null,arguments);bufferedOps.push(request);return deferreds[request.callback].promise();},postRequest=function(request){var data=structuredData?request:JSON.stringify(request);if(!usingPM){proxy.contentWindow.postMessage(data,proxyOrigin);}
else if(window.pm){pm({data:data,type:'proxy',target:proxy.contentWindow,url:'https://public-api.wordpress.com/wp-admin/rest-proxy/#'+origin,origin:proxyOrigin});}},buildRequest=function(){var args=jQuery.makeArray(arguments),request=args.pop(),path=args.pop(),deferred=new jQuery.Deferred(),deferred_id;if(jQuery.isFunction(request)){deferred.done(request);request=path;path=args.pop();}
if('string'===typeof(request)){request={path:request};}
if(path){request.path=path;}
do{deferred_id=Math.random();}while('undefined'!==typeof deferreds[deferred_id]);deferreds[deferred_id]=deferred;request.callback=deferred_id;request.supports_args=true;return request;};if(jQuery.inArray(typeof window.postMessage,['function','object'])!=-1){$(window).bind('message',check);window.postMessage({},origin);}else if(window.pm){usingPM=true;buildProxy();}else{supported=false;}
$.wpcom_proxy_request=function(){if(!supported){throw('Browser does not support window.postMessage');}
if(ready){return perform.apply(null,arguments);}else{return buffer.apply(null,arguments);}};$.wpcom_proxy_rebuild=function(){if(!ready)
return;ready=false;$(proxy).remove();buildProxy();};})(jQuery);