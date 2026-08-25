'use client';
import { ErrorState } from '@/components/ui';
export default function ErrorPage({reset}:{error:Error;reset:()=>void}){return <main><ErrorState/><button onClick={reset}>Try again</button></main>}
