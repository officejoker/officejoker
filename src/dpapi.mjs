/**
 * DPAPI 解密（保留兼容层，仅 Windows 数据文件）
 *
 * 老 上游网关把安装密钥和 OAuth 账号档案用 Windows DPAPI 加密落盘，
 * 文件格式是：
 *   OC-DPAPI-1
 *   <base64 的 DPAPI blob>
 *
 * Linux 容器里没有 DPAPI，这类加密档案一律读不出来 —— 这是预期行为：
 * 容器部署请用「面板自助登录」或手工导入的明文凭据（data/oauth-accounts.json）。
 * 这里保留 readProtectedText 的接口语义：遇到 OC-DPAPI-1 头直接返回 null，
 * 明文文件照常透传。进程内不再缓存、不再起 PowerShell 子进程。
 */

import fs from 'node:fs';

const DPAPI_HEADER = 'OC-DPAPI-1';

/**
 * 读一个 上游网关的 OC-DPAPI-1 文件；不是该格式就当明文返回。
 * 容器里遇到 OC-DPAPI-1 头一律返回 null，由调用方降级处理。
 */
export function readProtectedText(file) {
  let raw;
  try {
    raw = fs.readFileSync(file, 'utf8');
  } catch {
    return null;
  }
  const lines = raw.split(/\r?\n/).filter((l) => l.trim());
  if (lines.length === 0) return null;
  if (lines[0].trim() !== DPAPI_HEADER) return lines.join('\n');
  return null;
}

/** 供面板展示：DPAPI 通道状态（容器里恒为不可用） */
export function dpapiStatus() {
  return {
    available: false,
    cached: 0,
    failStreak: 0,
    platform: 'linux（容器内无 DPAPI，加密档案不可读；请用明文凭据 / 面板自助登录）',
  };
}

