type RpcClient={rpc:(name:string,args:Record<string,unknown>)=>PromiseLike<{data:unknown;error:{message:string}|null}>};
export async function consumeActionBudget(client:RpcClient,action:'INVITATION'|'PORTAL_ISSUE'|'PORTAL_REQUEST'|'DOCUMENT_UPLOAD'|'NOTIFICATION_TRIGGER',limit:number,windowSeconds:number){
 const {data,error}=await client.rpc('consume_action_budget',{p_action:action,p_limit:limit,p_window_seconds:windowSeconds});
 if(error||data!==true)throw new Error('Too many requests. Wait and try again.');
}
