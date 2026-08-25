import { defineConfig } from '@playwright/test';
import { loadEnvConfig } from '@next/env';
loadEnvConfig(__dirname);
export default defineConfig({
 testDir:'./e2e',fullyParallel:false,retries:0,workers:1,reporter:'list',
 use:{baseURL:'http://127.0.0.1:3100',trace:'retain-on-failure'},
 webServer:{command:'npm run dev -- --hostname 127.0.0.1 --port 3100',url:'http://127.0.0.1:3100/api/health',reuseExistingServer:false,timeout:120_000},
});
