var __defProp = Object.defineProperty;
var __name = (target, value) => __defProp(target, "name", { value, configurable: true });

// index.js
function parseBinaryPlist(buffer, baseOffset = 0) {
  const data = buffer instanceof Uint8Array ? buffer : new Uint8Array(buffer);
  const view = new DataView(data.buffer, data.byteOffset, data.byteLength);
  const trailerOffset = data.length - 32;
  const offsetSize = view.getUint8(trailerOffset + 6);
  const objectRefSize = view.getUint8(trailerOffset + 7);
  const objectCount = Number(view.getBigUint64(trailerOffset + 8));
  const topObject = Number(view.getBigUint64(trailerOffset + 16));
  const offsetTableOffset = Number(view.getBigUint64(trailerOffset + 24));
  const offsets = [];
  for (let i = 0; i < objectCount; i++) {
    let off = 0;
    for (let j = 0; j < offsetSize; j++) {
      off = off * 256 + view.getUint8(offsetTableOffset + baseOffset + i * offsetSize + j);
    }
    offsets.push(off);
  }
  function readObject(objIndex) {
    const offset = offsets[objIndex] + baseOffset;
    const marker = view.getUint8(offset);
    const type = marker >> 4 & 15;
    const size = marker & 15;
    switch (type) {
      case 0:
        return size === 0 ? null : size === 8 ? false : true;
      case 1: {
        const byteCount = 1 << size;
        let val = 0;
        for (let i = 0; i < byteCount; i++) val = val * 256 + view.getUint8(offset + 1 + i);
        return val;
      }
      case 2: {
        if (size === 2) return view.getFloat32(offset + 1);
        if (size === 3) return view.getFloat64(offset + 1);
        return 0;
      }
      case 3: {
        const secs = view.getFloat64(offset + 1);
        return new Date((secs + 978307200) * 1e3).toISOString();
      }
      case 4: {
        let len = size;
        let dataOff = offset + 1;
        if (len === 15) {
          const extMarker = view.getUint8(dataOff);
          const extType = extMarker >> 4 & 15;
          const extSize = extMarker & 15;
          if (extType === 1) {
            const byteCount = 1 << extSize;
            len = 0;
            for (let i = 0; i < byteCount; i++) {
              len = len * 256 + view.getUint8(dataOff + 1 + i);
            }
            dataOff += 1 + byteCount;
          }
        }
        return data.slice(dataOff, dataOff + len);
      }
      case 5: {
        let len = size;
        let strOff = offset + 1;
        if (len === 15) {
          const extMarker = view.getUint8(strOff);
          const extType = extMarker >> 4 & 15;
          const extSize = extMarker & 15;
          if (extType === 1) {
            const byteCount = 1 << extSize;
            len = 0;
            for (let i = 0; i < byteCount; i++) {
              len = len * 256 + view.getUint8(strOff + 1 + i);
            }
            strOff += 1 + byteCount;
          }
        }
        let s = "";
        for (let i = 0; i < len; i++) s += String.fromCharCode(view.getUint8(strOff + i));
        return s;
      }
      case 6: {
        let len = size;
        let strOff = offset + 1;
        if (len === 15) {
          const extMarker = view.getUint8(strOff);
          const extType = extMarker >> 4 & 15;
          const extSize = extMarker & 15;
          if (extType === 1) {
            const byteCount = 1 << extSize;
            len = 0;
            for (let i = 0; i < byteCount; i++) {
              len = len * 256 + view.getUint8(strOff + 1 + i);
            }
            strOff += 1 + byteCount;
          }
        }
        let s = "";
        for (let i = 0; i < len; i++) {
          s += String.fromCharCode(view.getUint16(strOff + i * 2));
        }
        return s;
      }
      case 8: {
        const byteCount = size + 1;
        let val = 0;
        for (let i = 0; i < byteCount; i++) val = val * 256 + view.getUint8(offset + 1 + i);
        return val;
      }
      case 10: {
        let len = size;
        let arrOff = offset + 1;
        if (len === 15) {
          const extMarker = view.getUint8(arrOff);
          len = 1 << (extMarker & 15);
          arrOff++;
        }
        const arr = [];
        for (let i = 0; i < len; i++) {
          let ref = 0;
          for (let j = 0; j < objectRefSize; j++) {
            ref = ref * 256 + view.getUint8(arrOff + i * objectRefSize + j);
          }
          arr.push(readObject(ref));
        }
        return arr;
      }
      case 13: {
        let len = size;
        let dictOff = offset + 1;
        if (len === 15) {
          const extMarker = view.getUint8(dictOff);
          len = 1 << (extMarker & 15);
          dictOff++;
        }
        const dict = {};
        for (let i = 0; i < len; i++) {
          let keyRef = 0, valRef = 0;
          for (let j = 0; j < objectRefSize; j++) {
            keyRef = keyRef * 256 + view.getUint8(dictOff + i * objectRefSize + j);
          }
          for (let j = 0; j < objectRefSize; j++) {
            valRef = valRef * 256 + view.getUint8(dictOff + len * objectRefSize + i * objectRefSize + j);
          }
          const key = readObject(keyRef);
          dict[key] = readObject(valRef);
        }
        return dict;
      }
      default:
        return null;
    }
  }
  __name(readObject, "readObject");
  return readObject(topObject);
}
__name(parseBinaryPlist, "parseBinaryPlist");
function packageIDToString(packageID) {
  if (typeof packageID === "string") return packageID;
  if (packageID instanceof Uint8Array) {
    if (packageID.length === 16) {
      const hex = toHex(packageID);
      return `${hex.slice(0, 8)}-${hex.slice(8, 12)}-${hex.slice(12, 16)}-${hex.slice(16, 20)}-${hex.slice(20, 32)}`.toUpperCase();
    }
    return toHex(packageID);
  }
  return String(packageID);
}
__name(packageIDToString, "packageIDToString");
async function extractContentKeyFrom3105(fileData, password = null) {
  const magic = new TextEncoder().encode("3105PATCH\0");
  const bytes = new Uint8Array(fileData);
  if (bytes.length < magic.length + 20) return null;
  for (let i = 0; i < magic.length; i++) {
    if (bytes[i] !== magic[i]) return null;
  }
  let envelope;
  try {
    envelope = parseBinaryPlist(bytes, magic.length);
  } catch {
    return null;
  }
  if (!envelope.isPasswordProtected) {
    const key = envelope.publicContentKey;
    if (key instanceof Uint8Array && key.length === 32) return key;
    return null;
  }
  if (!password || password.length === 0) return null;
  try {
    const salt = envelope.kdfSalt;
    const iterations = envelope.kdfIterations || 1e5;
    const wrappedKey = envelope.wrappedContentKey;
    if (!(salt instanceof Uint8Array) || !(wrappedKey instanceof Uint8Array)) return null;
    const derivedKey = await deriveKeyFromPassword(password, salt, iterations);
    if (wrappedKey.length < 28) return null;
    const nonce = wrappedKey.slice(0, 12);
    const ciphertext = wrappedKey.slice(12);
    const packageID = envelope.packageID;
    const aadVersion = envelope.keyAADVersion || envelope.schemaVersion;
    if (!packageID || !aadVersion) return null;
    const packageIDStr = packageIDToString(packageID);
    const aadString = `3105PATCH/v${aadVersion}/key/${packageIDStr}`;
    const keyAAD = new TextEncoder().encode(aadString);
    const unlockedKey = await aesGcmDecrypt(derivedKey, nonce, ciphertext, keyAAD);
    if (unlockedKey && unlockedKey.length === 32) return unlockedKey;
    return null;
  } catch (e) {
    safeLog("caught-error", e);
    safeLog("content-key-extraction-failed", e);
    return null;
  }
}
__name(extractContentKeyFrom3105, "extractContentKeyFrom3105");
async function deriveKeyFromPassword(password, salt, iterations) {
  const encoder = new TextEncoder();
  const passwordBuffer = encoder.encode(password);
  const hmacKey = await crypto.subtle.importKey(
    "raw",
    passwordBuffer,
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"]
  );
  const blockIndex = new Uint8Array(4);
  blockIndex[3] = 1;
  const saltWithIndex = new Uint8Array(salt.length + 4);
  saltWithIndex.set(salt, 0);
  saltWithIndex.set(blockIndex, salt.length);
  let u = await crypto.subtle.sign("HMAC", hmacKey, saltWithIndex);
  let result = new Uint8Array(u);
  for (let i = 1; i < iterations; i++) {
    u = await crypto.subtle.sign("HMAC", hmacKey, u);
    const uArray = new Uint8Array(u);
    for (let j = 0; j < result.length; j++) {
      result[j] ^= uArray[j];
    }
  }
  return result;
}
__name(deriveKeyFromPassword, "deriveKeyFromPassword");
async function aesGcmDecrypt(key, nonce, ciphertextWithTag, aad = new Uint8Array(0)) {
  try {
    const cryptoKey = await crypto.subtle.importKey(
      "raw",
      key,
      { name: "AES-GCM" },
      false,
      ["decrypt"]
    );
    const decrypted = await crypto.subtle.decrypt(
      {
        name: "AES-GCM",
        iv: nonce,
        tagLength: 128,
        // 16 bytes = 128 bits
        additionalData: aad
      },
      cryptoKey,
      ciphertextWithTag
    );
    return new Uint8Array(decrypted);
  } catch (e) {
    safeLog("caught-error", e);
    return null;
  }
}
__name(aesGcmDecrypt, "aesGcmDecrypt");
function toHex(uint8Array) {
  return Array.from(uint8Array).map((b) => b.toString(16).padStart(2, "0")).join("");
}
__name(toHex, "toHex");
function formatBytes(bytes) {
  if (bytes === 0) return "0 B";
  const k = 1024;
  const sizes = ["B", "KB", "MB", "GB"];
  const i = Math.floor(Math.log(bytes) / Math.log(k));
  return Math.round(bytes / Math.pow(k, i) * 100) / 100 + " " + sizes[i];
}
__name(formatBytes, "formatBytes");
async function cleanupR2Files(env, dryRun = true) {
  const results = {
    totalFiles: 0,
    validFiles: 0,
    orphanFiles: [],
    deletedFiles: []
  };
  const listed = await env.R2.list({ limit: 1e3 });
  results.totalFiles = listed.objects.length;
  const patches = await env.DB.prepare("SELECT id, file_key FROM patches").all();
  const validFileKeys = new Set(patches.results.map((p) => p.file_key).filter((fk) => fk));
  const seenIds = /* @__PURE__ */ new Map();
  for (const obj of listed.objects) {
    const key = obj.key;
    let patchId = null;
    if (key.includes(".3105")) {
      patchId = key.replace(".3105", "");
    } else if (key.startsWith("patches/")) {
      const parts = key.split("/");
      if (parts.length >= 2) {
        patchId = parts[1];
      }
    }
    if (patchId) {
      if (seenIds.has(patchId)) {
        results.orphanFiles.push({
          key,
          size: obj.size,
          reason: "duplicate",
          originalKey: seenIds.get(patchId)
        });
        if (!dryRun) {
          await env.R2.delete(key);
          results.deletedFiles.push(key);
        }
      } else if (!validFileKeys.has(key)) {
        results.orphanFiles.push({
          key,
          size: obj.size,
          reason: "orphan"
        });
        if (!dryRun) {
          await env.R2.delete(key);
          results.deletedFiles.push(key);
        }
      } else {
        seenIds.set(patchId, key);
        results.validFiles++;
      }
    }
  }
  return results;
}
__name(cleanupR2Files, "cleanupR2Files");
var workerRoutes = {
  async fetch(request, env) {
    const url = new URL(request.url);
    const path = url.pathname;
    const method = request.method;
    const debugBlocked = await guardDebugRoute(env, request, path);
    if (debugBlocked) return debugBlocked;
    if (path === "/debug/storage" && method === "GET") {
      const db = await env.DB.prepare("SELECT 1 AS test").first();
      return Response.json({ worker: "OK", d1: db?.test === 1 ? "OK" : "ERROR" });
    }
    if (path === "/debug/r2/list" && method === "GET") {
      const listed = await env.R2.list({ limit: 1e3 });
      const patches = await env.DB.prepare("SELECT id, name, file_key FROM patches").all();
      const validFileKeys = new Set(patches.results.map((p) => p.file_key).filter((fk) => fk));
      const files = listed.objects.map((obj) => ({
        key: obj.key,
        size: obj.size,
        sizeFormatted: formatBytes(obj.size),
        isValid: validFileKeys.has(obj.key),
        uploaded: obj.uploaded.toISOString()
      }));
      return Response.json({
        totalFiles: files.length,
        validFiles: files.filter((f) => f.isValid).length,
        orphanFiles: files.filter((f) => !f.isValid).length,
        truncated: listed.truncated,
        files
      });
    }
    if (path === "/debug/r2/count" && method === "GET") {
      let count = 0;
      let cursor = null;
      do {
        const listed = await env.R2.list({ limit: 1e3, cursor });
        count += listed.objects.length;
        cursor = listed.truncated ? listed.cursor : null;
      } while (cursor);
      return Response.json({
        totalFiles: count
      });
    }
    if (path === "/debug/r2/cleanup" && method === "GET") {
      const results = await cleanupR2Files(env, true);
      return Response.json({
        message: "Dry run - no files were deleted",
        ...results,
        orphanFiles: results.orphanFiles.map((f) => ({
          key: f.key,
          size: f.size,
          sizeFormatted: formatBytes(f.size),
          reason: f.reason,
          originalKey: f.originalKey
        }))
      });
    }
    if (path === "/debug/r2/cleanup" && method === "POST") {
      const results = await cleanupR2Files(env, false);
      return Response.json({
        message: "Cleanup completed - orphan/duplicate files deleted",
        ...results
      });
    }
    if (path === "/debug/r2/nuke" && method === "POST") {
      let deletedCount = 0;
      let cursor = null;
      do {
        const listed = await env.R2.list({ limit: 1e3, cursor });
        const deletePromises = listed.objects.map((obj) => env.R2.delete(obj.key));
        await Promise.all(deletePromises);
        deletedCount += listed.objects.length;
        cursor = listed.truncated ? listed.cursor : null;
      } while (cursor);
      return Response.json({
        message: `Deleted ${deletedCount} files from R2`,
        deletedCount
      });
    }
    if (path === "/debug/patches/duplicates" && method === "GET") {
      const patches = await env.DB.prepare("SELECT id, name, created_at FROM patches ORDER BY name, created_at").all();
      const byName = {};
      for (const p of patches.results) {
        if (!byName[p.name]) byName[p.name] = [];
        byName[p.name].push(p);
      }
      const duplicates = [];
      for (const [name, list] of Object.entries(byName)) {
        if (list.length > 1) {
          duplicates.push({
            name,
            count: list.length,
            patches: list.map((p, i) => ({
              id: p.id,
              created_at: p.created_at,
              keep: i === 0
              // Mantener el más antiguo
            }))
          });
        }
      }
      return Response.json({
        totalPatches: patches.results.length,
        duplicateGroups: duplicates.length,
        duplicates
      });
    }
    if (path === "/debug/patches/duplicates" && method === "POST") {
      const patches = await env.DB.prepare("SELECT id, name, file_key, created_at FROM patches ORDER BY name, created_at").all();
      const byName = {};
      for (const p of patches.results) {
        if (!byName[p.name]) byName[p.name] = [];
        byName[p.name].push(p);
      }
      let deletedCount = 0;
      const deletedIds = [];
      for (const [name, list] of Object.entries(byName)) {
        if (list.length > 1) {
          for (let i = 1; i < list.length; i++) {
            const p = list[i];
            if (p.file_key) {
              try {
                await env.R2.delete(p.file_key);
              } catch (e) {
                safeLog("caught-error", e);
              }
            }
            await env.DB.prepare("DELETE FROM patches WHERE id = ?").bind(p.id).run();
            await env.DB.prepare("DELETE FROM user_patches WHERE patch_id = ?").bind(p.id).run();
            await env.DB.prepare("DELETE FROM downloads WHERE patch_id = ?").bind(p.id).run();
            deletedCount++;
            deletedIds.push(p.id);
          }
        }
      }
      return Response.json({
        message: `Deleted ${deletedCount} duplicate patches`,
        deletedCount,
        deletedIds
      });
    }
    if (path.startsWith("/debug/patch/") && path.endsWith("/hexdump") && method === "GET") {
      const patchId = path.split("/")[3];
      const patch = await env.DB.prepare("SELECT file_key FROM patches WHERE id = ?").bind(patchId).first();
      if (!patch || !patch.file_key) {
        return Response.json({ error: "Patch or file not found" }, { status: 404 });
      }
      const object = await env.R2.get(patch.file_key);
      if (!object) {
        return Response.json({ error: "File not found in R2" });
      }
      const buffer = await object.arrayBuffer();
      const bytes = new Uint8Array(buffer);
      const hexDump = [];
      const limit = Math.min(512, bytes.length);
      for (let i = 0; i < limit; i += 16) {
        const hex = [];
        const ascii = [];
        for (let j = 0; j < 16 && i + j < bytes.length; j++) {
          const byte = bytes[i + j];
          hex.push(byte.toString(16).padStart(2, "0"));
          ascii.push(byte >= 32 && byte < 127 ? String.fromCharCode(byte) : ".");
        }
        hexDump.push(`${i.toString(16).padStart(4, "0")}: ${hex.join(" ")}  ${ascii.join("")}`);
      }
      const trailerOffset = bytes.length - 32;
      const view = new DataView(buffer);
      const offsetSize = view.getUint8(trailerOffset + 6);
      const objectRefSize = view.getUint8(trailerOffset + 7);
      const objectCount = Number(view.getBigUint64(trailerOffset + 8));
      const topObject = Number(view.getBigUint64(trailerOffset + 16));
      const offsetTableOffset = Number(view.getBigUint64(trailerOffset + 24));
      return Response.json({
        fileSize: bytes.length,
        magic: new TextDecoder().decode(bytes.slice(0, 10)),
        trailer: {
          offsetSize,
          objectRefSize,
          objectCount,
          topObject,
          offsetTableOffset
        },
        hexDump: hexDump.join("\n")
      });
    }
    if (path.startsWith("/debug/patch/") && path.endsWith("/test-extract") && method === "GET") {
      const patchId = path.split("/")[3];
      const testPassword = url.searchParams.get("password") || "";
      const patch = await env.DB.prepare("SELECT * FROM patches WHERE id = ?").bind(patchId).first();
      if (!patch) {
        return Response.json({ error: "Patch not found" }, { status: 404 });
      }
      const debugInfo = {
        patchId: patch.id,
        name: patch.name,
        dbPassword: patch.password || "(empty)",
        dbPasswordHex: patch.password ? toHex(new TextEncoder().encode(patch.password)) : "(empty)",
        dbPasswordLength: patch.password ? patch.password.length : 0,
        testPassword,
        testPasswordHex: toHex(new TextEncoder().encode(testPassword)),
        testPasswordLength: testPassword.length
      };
      if (!patch.file_key) {
        return Response.json({ ...debugInfo, error: "No file uploaded" });
      }
      try {
        const object = await env.R2.get(patch.file_key);
        if (!object) {
          return Response.json({ ...debugInfo, error: "File not found in R2" });
        }
        const fileBuffer = await object.arrayBuffer();
        const extractedWithDb = await extractContentKeyFrom3105(fileBuffer, patch.password || null);
        debugInfo.extractedWithDbPassword = extractedWithDb ? toHex(extractedWithDb) : "FAILED";
        if (testPassword) {
          const extractedWithTest = await extractContentKeyFrom3105(fileBuffer, testPassword);
          debugInfo.extractedWithTestPassword = extractedWithTest ? toHex(extractedWithTest) : "FAILED";
        }
        const password = testPassword || patch.password;
        if (password) {
          const magic = new TextEncoder().encode("3105PATCH\0");
          const bytes = new Uint8Array(fileBuffer);
          const envelope = parseBinaryPlist(bytes, magic.length);
          const salt = envelope.kdfSalt;
          const iterations = envelope.kdfIterations || 1e5;
          const wrappedKey = envelope.wrappedContentKey;
          debugInfo.step1_saltHex = toHex(salt);
          debugInfo.step2_iterations = iterations;
          debugInfo.step3_wrappedKeyHex = toHex(wrappedKey);
          const passwordBuffer = new TextEncoder().encode(password);
          debugInfo.step4_passwordBufferHex = toHex(passwordBuffer);
          const derivedKey = await deriveKeyFromPassword(password, salt, iterations);
          debugInfo.step5_derivedKeyHex = toHex(derivedKey);
          const nonce = wrappedKey.slice(0, 12);
          const ciphertext = wrappedKey.slice(12);
          debugInfo.step6_nonceHex = toHex(nonce);
          debugInfo.step7_ciphertextLength = ciphertext.length;
          const packageID = envelope.packageID;
          const aadVersion = envelope.keyAADVersion || envelope.schemaVersion;
          const aadString = `3105PATCH/v${aadVersion}/key/${packageID}`;
          debugInfo.step8_aadString = aadString;
          const keyAAD = new TextEncoder().encode(aadString);
          debugInfo.step9_aadHex = toHex(keyAAD);
          try {
            const cryptoKey = await crypto.subtle.importKey(
              "raw",
              derivedKey,
              { name: "AES-GCM" },
              false,
              ["decrypt"]
            );
            const decrypted = await crypto.subtle.decrypt(
              {
                name: "AES-GCM",
                iv: nonce,
                tagLength: 128,
                additionalData: keyAAD
              },
              cryptoKey,
              ciphertext
            );
            const unlockedKey = new Uint8Array(decrypted);
            debugInfo.step10_decryptionSuccess = true;
            debugInfo.step11_contentKeyHex = toHex(unlockedKey);
            debugInfo.success = true;
          } catch (decryptError) {
            debugInfo.step10_decryptionSuccess = false;
            safeLog("decrypt-failed", decryptError);
            debugInfo.step10_decryptError = "Operation failed";
          }
        }
        return Response.json(debugInfo);
      } catch (e) {
        safeLog("caught-error", e);
        return Response.json({ ...debugInfo, error: "Internal server error" });
      }
    }
    if (path === "/debug/patches" && method === "GET") {
      const patches = await env.DB.prepare("SELECT id, name, password, content_key, file_key, created_at FROM patches ORDER BY created_at DESC").all();
      const results = [];
      for (const patch of patches.results) {
        const info = {
          id: patch.id,
          name: patch.name,
          hasPassword: !!patch.password && patch.password.length > 0,
          passwordLength: patch.password ? patch.password.length : 0,
          hasContentKey: !!patch.content_key && patch.content_key.length > 0,
          contentKey: patch.content_key || "(empty)",
          hasFile: !!patch.file_key,
          created_at: patch.created_at
        };
        if (patch.file_key) {
          try {
            const object = await env.R2.get(patch.file_key);
            if (!object) {
              info.error = "File not found in R2";
            } else {
              const fileBuffer = await object.arrayBuffer();
              info.fileSize = fileBuffer.byteLength;
              const magic = new TextEncoder().encode("3105PATCH\0");
              const bytes = new Uint8Array(fileBuffer);
              if (bytes.length < magic.length + 20) {
                info.error = "File too small";
              } else {
                let magicOk = true;
                for (let i = 0; i < magic.length; i++) {
                  if (bytes[i] !== magic[i]) {
                    magicOk = false;
                    break;
                  }
                }
                if (!magicOk) {
                  info.error = "Invalid magic header";
                } else {
                  try {
                    const plistData = bytes.slice(magic.length);
                    const envelope = parseBinaryPlist(plistData);
                    info.envelopeKeys = Object.keys(envelope);
                    info.isPasswordProtected = envelope.isPasswordProtected;
                    info.packageID = envelope.packageID;
                    info.packageIDType = typeof envelope.packageID;
                    info.schemaVersion = envelope.schemaVersion;
                    info.keyAADVersion = envelope.keyAADVersion;
                    info.hasKdfSalt = envelope.kdfSalt instanceof Uint8Array;
                    info.kdfSaltLength = envelope.kdfSalt ? envelope.kdfSalt.length : 0;
                    info.hasWrappedKey = envelope.wrappedContentKey instanceof Uint8Array;
                    info.wrappedKeyLength = envelope.wrappedContentKey ? envelope.wrappedContentKey.length : 0;
                    info.hasPublicKey = envelope.publicContentKey instanceof Uint8Array;
                    info.kdfIterations = envelope.kdfIterations;
                  } catch (e) {
                    safeLog("caught-error", e);
                    info.error = "Operation failed";
                  }
                }
              }
            }
          } catch (e) {
            safeLog("caught-error", e);
            info.error = "Operation failed";
          }
        }
        results.push(info);
      }
      return Response.json({ patches: results });
    }
    if (path.startsWith("/debug/patch/") && method === "GET") {
      const patchId = path.split("/")[3];
      const patch = await env.DB.prepare("SELECT * FROM patches WHERE id = ?").bind(patchId).first();
      if (!patch) {
        return Response.json({ error: "Patch not found" }, { status: 404 });
      }
      const debugInfo = {
        patchId: patch.id,
        name: patch.name,
        hasPassword: !!patch.password && patch.password.length > 0,
        passwordLength: patch.password ? patch.password.length : 0,
        currentContentKey: patch.content_key || "(empty)",
        fileKey: patch.file_key || "(no file)"
      };
      if (!patch.file_key) {
        return Response.json({ ...debugInfo, error: "No file uploaded" });
      }
      try {
        const object = await env.R2.get(patch.file_key);
        if (!object) {
          return Response.json({ ...debugInfo, error: "File not found in R2" });
        }
        const fileBuffer = await object.arrayBuffer();
        debugInfo.fileSize = fileBuffer.byteLength;
        const extracted = await extractContentKeyFrom3105(fileBuffer, patch.password || null);
        if (extracted) {
          debugInfo.success = true;
          debugInfo.extractedContentKey = toHex(extracted);
          debugInfo.contentKeyLength = extracted.length;
        } else {
          debugInfo.success = false;
          debugInfo.error = "Failed to extract content_key";
          const magic = new TextEncoder().encode("3105PATCH\0");
          const bytes = new Uint8Array(fileBuffer);
          if (bytes.length < magic.length + 20) {
            debugInfo.diagnostic = "File too small";
          } else {
            let magicOk = true;
            for (let i = 0; i < magic.length; i++) {
              if (bytes[i] !== magic[i]) {
                magicOk = false;
                break;
              }
            }
            if (!magicOk) {
              debugInfo.diagnostic = "Invalid magic header (not a .3105 file)";
            } else {
              try {
                const plistData = bytes.slice(magic.length);
                const envelope = parseBinaryPlist(plistData);
                debugInfo.diagnostic = "Parsed envelope successfully";
                debugInfo.envelopeKeys = Object.keys(envelope);
                debugInfo.isPasswordProtected = envelope.isPasswordProtected;
                debugInfo.packageID = envelope.packageID;
                debugInfo.schemaVersion = envelope.schemaVersion;
                debugInfo.keyAADVersion = envelope.keyAADVersion;
                debugInfo.hasKdfSalt = envelope.kdfSalt instanceof Uint8Array;
                debugInfo.hasWrappedKey = envelope.wrappedContentKey instanceof Uint8Array;
                debugInfo.hasPublicKey = envelope.publicContentKey instanceof Uint8Array;
                if (envelope.isPasswordProtected) {
                  if (!patch.password || patch.password.length === 0) {
                    debugInfo.diagnostic += " \u2014 Password protected but no password in DB";
                  } else {
                    debugInfo.diagnostic += " \u2014 Password provided but extraction failed (wrong password?)";
                  }
                }
              } catch (e) {
                safeLog("caught-error", e);
                debugInfo.diagnostic = "Operation failed";
              }
            }
          }
        }
      } catch (e) {
        safeLog("caught-error", e);
        debugInfo.error = "Operation failed";
      }
      return Response.json(debugInfo);
    }
    if (path.startsWith("/debug/patch/") && path.endsWith("/extract") && method === "POST") {
      const patchId = path.split("/")[3];
      const patch = await env.DB.prepare("SELECT * FROM patches WHERE id = ?").bind(patchId).first();
      if (!patch) {
        return Response.json({ error: "Patch not found" }, { status: 404 });
      }
      if (!patch.file_key) {
        return Response.json({ error: "No file uploaded" });
      }
      try {
        const object = await env.R2.get(patch.file_key);
        if (!object) {
          return Response.json({ error: "File not found in R2" });
        }
        const fileBuffer = await object.arrayBuffer();
        const extracted = await extractContentKeyFrom3105(fileBuffer, patch.password || null);
        if (extracted) {
          const contentKeyHex = toHex(extracted);
          await env.DB.prepare("UPDATE patches SET content_key = ? WHERE id = ?").bind(contentKeyHex, patchId).run();
          return Response.json({
            success: true,
            contentKey: contentKeyHex,
            message: "Content key extracted and saved"
          });
        } else {
          return Response.json({
            success: false,
            error: "Failed to extract content_key. Check password."
          });
        }
      } catch (e) {
        safeLog("caught-error", e);
        return Response.json({ error: "Internal server error" });
      }
    }
    if (path.startsWith("/debug/patch/") && path.endsWith("/extract-debug") && method === "GET") {
      const patchId = path.split("/")[3];
      const patch = await env.DB.prepare("SELECT * FROM patches WHERE id = ?").bind(patchId).first();
      if (!patch) {
        return Response.json({ error: "Patch not found" }, { status: 404 });
      }
      if (!patch.file_key) {
        return Response.json({ error: "No file uploaded" });
      }
      const debugInfo = {
        patchId: patch.id,
        name: patch.name,
        password: patch.password || "(empty)",
        passwordLength: patch.password ? patch.password.length : 0
      };
      try {
        const object = await env.R2.get(patch.file_key);
        if (!object) {
          return Response.json({ ...debugInfo, error: "File not found in R2" });
        }
        const fileBuffer = await object.arrayBuffer();
        const bytes = new Uint8Array(fileBuffer);
        debugInfo.fileSize = bytes.length;
        const magic = new TextEncoder().encode("3105PATCH\0");
        debugInfo.magicHex = toHex(bytes.slice(0, 10));
        debugInfo.magicExpected = toHex(magic);
        let magicOk = true;
        for (let i = 0; i < magic.length; i++) {
          if (bytes[i] !== magic[i]) {
            magicOk = false;
            break;
          }
        }
        debugInfo.magicValid = magicOk;
        if (!magicOk) {
          return Response.json({ ...debugInfo, error: "Invalid magic header" });
        }
        let envelope;
        try {
          envelope = parseBinaryPlist(bytes, magic.length);
          debugInfo.envelopeParsed = true;
          debugInfo.envelopeKeys = Object.keys(envelope);
        } catch (e) {
          safeLog("caught-error", e);
          return Response.json({ ...debugInfo, error: "Invalid binary plist" });
        }
        debugInfo.isPasswordProtected = envelope.isPasswordProtected;
        debugInfo.isPasswordProtectedType = typeof envelope.isPasswordProtected;
        debugInfo.packageID = envelope.packageID;
        debugInfo.packageIDType = typeof envelope.packageID;
        if (envelope.packageID instanceof Uint8Array) {
          debugInfo.packageIDHex = toHex(envelope.packageID);
          debugInfo.packageIDLength = envelope.packageID.length;
        }
        debugInfo.schemaVersion = envelope.schemaVersion;
        debugInfo.keyAADVersion = envelope.keyAADVersion;
        debugInfo.kdfIterations = envelope.kdfIterations;
        if (envelope.kdfSalt instanceof Uint8Array) {
          debugInfo.kdfSaltHex = toHex(envelope.kdfSalt);
          debugInfo.kdfSaltLength = envelope.kdfSalt.length;
        } else {
          debugInfo.kdfSaltType = typeof envelope.kdfSalt;
        }
        if (envelope.wrappedContentKey instanceof Uint8Array) {
          debugInfo.wrappedKeyHex = toHex(envelope.wrappedContentKey);
          debugInfo.wrappedKeyLength = envelope.wrappedContentKey.length;
        } else {
          debugInfo.wrappedKeyType = typeof envelope.wrappedContentKey;
        }
        if (envelope.publicContentKey instanceof Uint8Array) {
          debugInfo.publicKeyHex = toHex(envelope.publicContentKey);
          debugInfo.publicKeyLength = envelope.publicContentKey.length;
        }
        if (!envelope.isPasswordProtected) {
          if (envelope.publicContentKey instanceof Uint8Array && envelope.publicContentKey.length === 32) {
            debugInfo.success = true;
            debugInfo.extractedKeyHex = toHex(envelope.publicContentKey);
            debugInfo.method = "direct (no password)";
          } else {
            debugInfo.error = "Not password protected but publicContentKey invalid";
          }
          return Response.json(debugInfo);
        }
        if (!patch.password || patch.password.length === 0) {
          debugInfo.error = "Password protected but no password in DB";
          return Response.json(debugInfo);
        }
        debugInfo.derivationStep = "Starting PBKDF2";
        const salt = envelope.kdfSalt;
        const iterations = envelope.kdfIterations || 1e5;
        try {
          const passwordBuffer = new TextEncoder().encode(patch.password);
          debugInfo.derivationStep = "Deriving bits";
          const derivedKey = await deriveKeyFromPassword(patch.password, salt, iterations);
          debugInfo.derivedKeyHex = toHex(derivedKey);
          debugInfo.derivationStep = "Key derived successfully";
          const wrappedKey = envelope.wrappedContentKey;
          if (wrappedKey.length < 28) {
            debugInfo.error = "Wrapped key too short: " + wrappedKey.length;
            return Response.json(debugInfo);
          }
          const nonce = wrappedKey.slice(0, 12);
          const ciphertext = wrappedKey.slice(12);
          debugInfo.nonceHex = toHex(nonce);
          debugInfo.ciphertextLength = ciphertext.length;
          const packageID = envelope.packageID;
          const aadVersion = envelope.keyAADVersion || envelope.schemaVersion;
          let packageIDString;
          if (typeof packageID === "string") {
            packageIDString = packageID;
          } else if (packageID instanceof Uint8Array) {
            const hex = toHex(packageID);
            packageIDString = `${hex.slice(0, 8)}-${hex.slice(8, 12)}-${hex.slice(12, 16)}-${hex.slice(16, 20)}-${hex.slice(20, 32)}`.toUpperCase();
          } else {
            packageIDString = String(packageID);
          }
          debugInfo.packageIDString = packageIDString;
          const aadString = `3105PATCH/v${aadVersion}/key/${packageIDString}`;
          debugInfo.aadString = aadString;
          const keyAAD = new TextEncoder().encode(aadString);
          debugInfo.aadHex = toHex(keyAAD);
          debugInfo.derivationStep = "Decrypting wrapped key";
          const cryptoKey = await crypto.subtle.importKey(
            "raw",
            derivedKey,
            { name: "AES-GCM" },
            false,
            ["decrypt"]
          );
          try {
            const decrypted = await crypto.subtle.decrypt(
              {
                name: "AES-GCM",
                iv: nonce,
                tagLength: 128,
                additionalData: keyAAD
              },
              cryptoKey,
              ciphertext
            );
            const unlockedKey = new Uint8Array(decrypted);
            debugInfo.derivationStep = "Decryption successful";
            if (unlockedKey.length === 32) {
              debugInfo.success = true;
              debugInfo.extractedKeyHex = toHex(unlockedKey);
              debugInfo.method = "password-derived";
            } else {
              debugInfo.error = "Decrypted key wrong length: " + unlockedKey.length;
            }
          } catch (decryptError) {
            debugInfo.derivationStep = "Decryption failed";
            safeLog("decrypt-failed", decryptError);
            debugInfo.decryptError = "Operation failed";
            debugInfo.error = "AES-GCM decrypt failed. Wrong password or AAD mismatch.";
          }
        } catch (deriveError) {
          debugInfo.derivationStep = "Key derivation failed";
          safeLog("key-derivation-failed", deriveError);
          debugInfo.deriveError = "Operation failed";
          debugInfo.error = "Key derivation failed";
        }
        return Response.json(debugInfo);
      } catch (e) {
        safeLog("caught-error", e);
        return Response.json({ ...debugInfo, error: "Internal server error" });
      }
    }
    if ((path === "/admin" || path === "/admin.html" || path === "/admin/") && method === "GET") {
      try {
        const adminHtml = await env.R2.get("admin-panel/index.html");
        if (adminHtml) {
          const html = (await adminHtml.text()).replace("alert('Credenciales inv\xE1lidas');", "alert(res.status === 503 ? 'Servicio de autenticaci\xF3n no disponible. Contacta al administrador.' : res.status === 429 ? 'Demasiados intentos. Espera antes de volver a intentar.' : res.status >= 500 ? 'Error del servicio. Int\xE9ntalo m\xE1s tarde.' : 'Credenciales inv\xE1lidas');");
          return new Response(html, {
            headers: {
              "Content-Type": "text/html; charset=utf-8",
              "Cache-Control": "no-cache"
            }
          });
        }
        return new Response("Admin panel not found", { status: 404 });
      } catch (e) {
        safeLog("caught-error", e);
        safeLog("admin panel:", e);
        return new Response("Error loading admin panel", { status: 500 });
      }
    }
    if (method === "OPTIONS") {
      return new Response(null, {
        headers: {
          "Access-Control-Allow-Origin": "*",
          "Access-Control-Allow-Methods": "GET, POST, PUT, DELETE, OPTIONS",
          "Access-Control-Allow-Headers": "Content-Type, Authorization"
        }
      });
    }
    const corsHeaders = {
      "Access-Control-Allow-Origin": "*",
      "Content-Type": "application/json"
    };
    try {
      if (path === "/v1/device-check" && method === "POST") {
        return await handleV1DeviceCheck(request, env, corsHeaders);
      }
      if (path === "/v1/activations" && method === "POST") {
        return await handleV1Activation(request, env, corsHeaders);
      }
      if (path === "/v1/challenges" && method === "POST") {
        return await handleV1Challenge(request, env, corsHeaders);
      }
      if (path === "/v1/verifications" && method === "POST") {
        return await handleV1Verification(request, env, corsHeaders);
      }
      if (path === "/v1/telemetry" && method === "POST") {
        return await handleV1Telemetry(request, env, corsHeaders);
      }
      if (path === "/api/app/validate-license" && method === "POST") {
        return await handleAppValidateLicense(request, env, corsHeaders);
      }
      if (path.startsWith("/api/app/")) {
        const appAuth = await verifyAppAuth(request, env);
        if (!appAuth.valid) {
          return Response.json({ error: "Unauthorized", valid: false }, { status: 401, headers: corsHeaders });
        }
        if (path === "/api/app/config" && method === "GET") {
          return await handleAppGetConfig(env, corsHeaders);
        }
        if (path === "/api/app/patches" && method === "GET") {
          return await handleAppGetPatches(env, corsHeaders, appAuth);
        }
        if (path.match(/^\/api\/app\/patches\/[^/]+$/) && method === "GET") {
          const id = path.split("/")[4];
          return await handleAppGetPatchDetail(id, env, corsHeaders, appAuth);
        }
        if (path.match(/^\/api\/app\/patches\/[^/]+\/download$/) && method === "GET") {
          const id = path.split("/")[4];
          return await handleAppDownloadPatch(id, env, corsHeaders, appAuth);
        }
        if (path === "/api/app/messages" && method === "GET") {
          return await handleAppGetMessages(env, corsHeaders, appAuth);
        }
        if (path.match(/^\/api\/app\/messages\/[^/]+\/ack$/) && method === "POST") {
          const id = path.split("/")[4];
          return await handleAppAckMessage(id, env, corsHeaders, appAuth);
        }
        if (path === "/api/app/telemetry" && method === "POST") {
          return await handleAppTelemetry(request, env, corsHeaders, appAuth);
        }
      }
      if (path === "/api/admin/login" && method === "POST") {
        return await handleLogin(request, env, corsHeaders);
      }
      const auth = await verifyAuth(request, env);
      if (!auth.valid) {
        return Response.json({ error: "Unauthorized" }, { status: 401, headers: corsHeaders });
      }
      if (path === "/api/licenses/activations" && method === "GET") {
        return await handleLicListActivations(env, corsHeaders);
      }
      if (path === "/api/licenses/devices" && method === "GET") {
        return await handleLicListDevices(env, corsHeaders);
      }
      if (path.match(/^\/api\/licenses\/activations\/[^/]+$/) && method === "DELETE") {
        return await handleLicDeleteActivation(path.split("/")[4], env, corsHeaders);
      }
      if (path === "/api/licenses/blocked" && method === "GET") {
        return await handleLicListBlocked(env, corsHeaders);
      }
      if (path === "/api/licenses/blocked" && method === "POST") {
        return await handleLicBlockDevice(request, env, corsHeaders);
      }
      if (path.match(/^\/api\/licenses\/blocked\/[^/]+$/) && method === "DELETE") {
        return await handleLicUnblockDevice(decodeURIComponent(path.split("/")[4]), env, corsHeaders);
      }
      if (path === "/api/licenses/signing-key" && method === "GET") {
        return await handleLicSigningKey(env, corsHeaders);
      }
      if (path === "/api/dashboard/stats" && method === "GET") {
        return await handleDashboardStats(env, corsHeaders);
      }
      if (path === "/api/dashboard/activity" && method === "GET") {
        return await handleDashboardActivity(env, corsHeaders);
      }
      if (path === "/api/users" && method === "GET") {
        return await handleGetUsers(env, corsHeaders, url);
      }
      if (path === "/api/users" && method === "POST") {
        return await handleCreateUser(request, env, corsHeaders);
      }
      if (path.match(/^\/api\/users\/[^/]+$/) && method === "PUT") {
        const id = path.split("/")[3];
        return await handleUpdateUser(id, request, env, corsHeaders);
      }
      if (path.match(/^\/api\/users\/[^/]+\/pause$/) && method === "POST") {
        const id = path.split("/")[3];
        return await handleTogglePause(id, env, corsHeaders);
      }
      if (path.match(/^\/api\/users\/[^/]+\/adjust-days$/) && method === "POST") {
        return handleAdjustDays(path.split("/")[3], request, env, corsHeaders);
      }
      if (path.match(/^\/api\/users\/[^/]+\/hwid$/) && method === "POST") {
        const id = path.split("/")[3];
        return await handleResetHWID(id, env, corsHeaders);
      }
      if (path.match(/^\/api\/users\/[^/]+\/block$/) && method === "POST") {
        const id = path.split("/")[3];
        return await handleToggleBlock(id, env, corsHeaders);
      }
      if (path.match(/^\/api\/users\/[^/]+\/renew$/) && method === "POST") {
        const id = path.split("/")[3];
        return await handleRenewLicense(id, request, env, corsHeaders);
      }
      if (path.match(/^\/api\/users\/[^/]+$/) && method === "DELETE") {
        const id = path.split("/")[3];
        return await handleDeleteUser(id, env, corsHeaders);
      }
      if (path === "/api/patches" && method === "GET") {
        return await handleGetPatches(env, corsHeaders, url);
      }
      if (path === "/api/patches" && method === "POST") {
        return await handleCreatePatch(request, env, corsHeaders);
      }
      if (path.match(/^\/api\/patches\/[^/]+$/) && method === "PUT") {
        const id = path.split("/")[3];
        return await handleUpdatePatch(id, request, env, corsHeaders);
      }
      if (path.match(/^\/api\/patches\/[^/]+$/) && method === "DELETE") {
        const id = path.split("/")[3];
        return await handleDeletePatch(id, env, corsHeaders);
      }
      if (path.match(/^\/api\/patches\/[^/]+\/toggle$/) && method === "POST") {
        const id = path.split("/")[3];
        return await handleTogglePatch(id, env, corsHeaders);
      }
      if (path === "/api/access" && method === "GET") {
        return await handleGetAccess(env, corsHeaders);
      }
      if (path === "/api/access" && method === "POST") {
        return await handleGrantAccess(request, env, corsHeaders);
      }
      if (path === "/api/access" && method === "DELETE") {
        return await handleRevokeAccess(request, env, corsHeaders);
      }
      if (path === "/api/messages" && method === "GET") {
        return await handleGetMessages(env, corsHeaders);
      }
      if (path === "/api/messages" && method === "POST") {
        return await handleCreateMessage(request, env, corsHeaders);
      }
      if (path.match(/^\/api\/messages\/[^/]+$/) && method === "PUT") {
        const id = path.split("/")[3];
        return await handleUpdateMessage(id, request, env, corsHeaders);
      }
      if (path.match(/^\/api\/messages\/[^/]+$/) && method === "DELETE") {
        const id = path.split("/")[3];
        return await handleDeleteMessage(id, env, corsHeaders);
      }
      if (path.match(/^\/api\/messages\/[^/]+\/toggle$/) && method === "POST") {
        const id = path.split("/")[3];
        return await handleToggleMessage(id, env, corsHeaders);
      }
      if (path === "/api/stats" && method === "GET") {
        return await handleStats(env, corsHeaders, url);
      }
      if (path === "/api/activity" && method === "GET") {
        return await handleGetActivity(env, corsHeaders, url);
      }
      if (path === "/api/config" && method === "GET") {
        return await handleGetConfig(env, corsHeaders);
      }
      if (path === "/api/config" && method === "PUT") {
        return await handleUpdateConfig(request, env, corsHeaders);
      }
      return Response.json({ error: "Not found" }, { status: 404, headers: corsHeaders });
    } catch (err) {
      return safeFailure(err, corsHeaders);
    }
  }
};
async function verifyAppAuth(request, env) {
  const authHeader = request.headers.get("Authorization");
  if (!authHeader || !authHeader.startsWith("Bearer ")) return { valid: false };
  const token = authHeader.slice(7).trim();
  const parts = token.split(".");
  if (parts.length !== 3 || !parts[0] || !parts[1] || !parts[2]) return { valid: false };
  try {
    const header = JSON.parse(atob(parts[0]));
    const payload = JSON.parse(atob(parts[1]));
    const secret = await sessionVerificationKey(env, header, payload, "app");
    if (!secret) return { valid: false };
    if (!header || header.alg !== "HS256" || header.typ !== "JWT") return { valid: false };
    if (payload?.role === "admin" || payload?.user !== void 0) return { valid: false };
    if (!payload || typeof payload.userId !== "string" || payload.userId.length === 0) return { valid: false };
    if (typeof payload.exp !== "number" || payload.exp <= Date.now()) return { valid: false };
    const expected = await hmacSign(parts[0] + "." + parts[1], secret);
    if (!await v1TimingSafeStrEq(expected, parts[2])) return { valid: false };
    const user = await env.DB.prepare("SELECT * FROM users WHERE id = ?").bind(payload.userId).first();
    if (!user) return { valid: false };
    if (!user.is_active || user.is_paused || user.is_blocked) return { valid: false };
    if (payload.licenseKey && user.license_key !== payload.licenseKey) return { valid: false };
    if (user.license_expires_at) {
      const expiresAt = new Date(user.license_expires_at);
      if (isNaN(expiresAt.getTime()) || expiresAt <= /* @__PURE__ */ new Date()) return { valid: false };
    }
    return { valid: true, userId: payload.userId, hwid: payload.hwid, user };
  } catch {
    return { valid: false };
  }
}
__name(verifyAppAuth, "verifyAppAuth");
async function handleAppValidateLicense(request, env, headers) {
  if (!v1JwtSecret(env)) return v1ConfigError(headers, env.AUTH_JWT_SECRET !== void 0 ? "AUTH_JWT_SECRET" : "JWT_SECRET");
  const { value: body, error } = await v1ReadJson(request, 4096);
  if (error) {
    return Response.json({ valid: false, error: "Invalid request" }, { status: 400, headers });
  }
  const licenseKey = typeof body.licenseKey === "string" ? body.licenseKey.trim() : "";
  const hwid = typeof body.hwid === "string" ? body.hwid.trim() : "";
  if (!licenseKey || licenseKey.length > 200) {
    return Response.json({ valid: false, error: "License key required" }, { status: 400, headers });
  }
  if (hwid.length > 200) {
    return Response.json({ valid: false, error: "Invalid request" }, { status: 400, headers });
  }
  const subject = await v1AttemptSubject("app_login", licenseKey, v1ClientIp(request));
  if (await v1RateExceeded(env, "app_login", subject, 20, 6e5)) {
    return Response.json({ valid: false, error: "Too many attempts" }, { status: 429, headers });
  }
  const user = await env.DB.prepare("SELECT * FROM users WHERE license_key = ?").bind(licenseKey).first();
  if (!user) {
    return Response.json({ valid: false, error: "Invalid license key" }, { status: 401, headers });
  }
  if (!user.is_active) {
    return Response.json({ valid: false, error: "Account inactive" }, { status: 403, headers });
  }
  if (user.is_blocked) {
    return Response.json({ valid: false, error: "Account blocked" }, { status: 403, headers });
  }
  if (user.is_paused) {
    return Response.json({ valid: false, error: "Account paused" }, { status: 403, headers });
  }
  if (user.license_expires_at) {
    const expiresAt = new Date(user.license_expires_at);
    if (isNaN(expiresAt.getTime()) || expiresAt < /* @__PURE__ */ new Date()) {
      return Response.json({
        valid: false,
        error: "License expired",
        expiredAt: user.license_expires_at
      }, { status: 403, headers });
    }
  }
  if (user.hwid && user.hwid !== "" && user.hwid !== hwid) {
    return Response.json({ valid: false, error: "HWID mismatch" }, { status: 403, headers });
  }
  if (!user.hwid || user.hwid === "") {
    await env.DB.prepare("UPDATE users SET hwid = ? WHERE id = ?").bind(hwid, user.id).run();
  }
  const exp = Date.now() + 864e5;
  const token = await createJWT({ userId: user.id, licenseKey, hwid, exp }, env);
  await logActivity(env, "app_login", "User " + user.username + " logged in");
  return Response.json({
    valid: true,
    token,
    expiresAt: new Date(exp).toISOString(),
    username: user.username,
    isPremium: !!user.is_premium,
    licenseExpiresAt: user.license_expires_at || null
  }, { headers });
}
__name(handleAppValidateLicense, "handleAppValidateLicense");
async function handleAppGetConfig(env, headers) {
  const result = await env.DB.prepare("SELECT key, value FROM config").all();
  const config = {};
  result.results.forEach((r) => {
    config[r.key] = r.value;
  });
  return Response.json(config, { headers });
}
__name(handleAppGetConfig, "handleAppGetConfig");
async function handleAppGetPatches(env, headers, appAuth) {
  const result = await env.DB.prepare(`
    SELECT p.id, p.name, p.description, p.version, p.type, p.file_key, p.password, p.content_key, p.created_at, p.updated_at
    FROM patches p
    INNER JOIN user_patches up ON up.patch_id = p.id
    WHERE p.active = 1
      AND up.user_id = ?
    ORDER BY p.created_at DESC
  `).bind(appAuth.userId).all();
  const patches = result.results.map((p) => ({
    id: p.id,
    name: p.name,
    description: p.description,
    version: p.version,
    type: p.type,
    status: "available",
    password: p.password || null,
    content_key: p.content_key || null,
    created_at: p.created_at,
    updated_at: p.updated_at
  }));
  return Response.json({ patches }, { headers });
}
__name(handleAppGetPatches, "handleAppGetPatches");
async function handleAppGetPatchDetail(id, env, headers, appAuth) {
  const patch = await env.DB.prepare(`
    SELECT p.* FROM patches p
    INNER JOIN user_patches up ON up.patch_id = p.id
    WHERE p.id = ? AND up.user_id = ? AND p.active = 1
  `).bind(id, appAuth.userId).first();
  if (!patch) {
    return Response.json({ error: "Patch not found or access denied" }, { status: 404, headers });
  }
  return Response.json({
    id: patch.id,
    name: patch.name,
    description: patch.description,
    version: patch.version,
    type: patch.type,
    status: "available",
    file_size: patch.file_key ? "unknown" : 0,
    password: patch.password || null,
    content_key: patch.content_key || null,
    created_at: patch.created_at,
    updated_at: patch.updated_at
  }, { headers });
}
__name(handleAppGetPatchDetail, "handleAppGetPatchDetail");
async function handleAppDownloadPatch(id, env, headers, appAuth) {
  const patch = await env.DB.prepare(`
    SELECT p.* FROM patches p
    INNER JOIN user_patches up ON up.patch_id = p.id
    WHERE p.id = ? AND up.user_id = ? AND p.active = 1
  `).bind(id, appAuth.userId).first();
  if (!patch) {
    return Response.json({ error: "Patch not found or access denied" }, { status: 404, headers });
  }
  if (!patch.file_key) {
    return Response.json({ error: "Patch has no file" }, { status: 400, headers });
  }
  const object = await env.R2.get(patch.file_key);
  if (!object) {
    return Response.json({ error: "File not found in storage" }, { status: 404, headers });
  }
  const downloadId = crypto.randomUUID();
  await env.DB.prepare(
    "INSERT INTO downloads (id, user_id, patch_id, created_at) VALUES (?, ?, ?, ?)"
  ).bind(downloadId, appAuth.userId, id, (/* @__PURE__ */ new Date()).toISOString()).run();
  const filename = patch.file_key.split("/").pop() || `patch_${id}.3105`;
  const responseHeaders = {
    "Access-Control-Allow-Origin": "*",
    "Content-Type": "application/octet-stream",
    "Content-Disposition": `attachment; filename="${filename}"`,
    "Content-Length": String(object.size),
    "X-Patch-Id": id,
    "X-Patch-Version": patch.version,
    "X-Patch-Name": patch.name
  };
  if (patch.content_key && patch.content_key !== "") {
    responseHeaders["X-Content-Key"] = patch.content_key;
  }
  if (patch.password && patch.password !== "") {
    responseHeaders["X-Patch-Password"] = patch.password;
  }
  return new Response(object.body, { headers: responseHeaders });
}
__name(handleAppDownloadPatch, "handleAppDownloadPatch");
async function handleAppGetMessages(env, headers, appAuth) {
  const result = await env.DB.prepare(`
    SELECT id, title, content, type, created_at
    FROM messages
    WHERE active = 1
      AND (target_hwid IS NULL OR target_hwid = '' OR target_hwid = ?)
    ORDER BY created_at DESC
  `).bind(appAuth.hwid).all();
  return Response.json({ messages: result.results }, { headers });
}
__name(handleAppGetMessages, "handleAppGetMessages");
async function handleAppAckMessage(id, env, headers, appAuth) {
  await logActivity(env, "message_ack", `User ${appAuth.userId} ack message ${id}`);
  return Response.json({ success: true }, { headers });
}
__name(handleAppAckMessage, "handleAppAckMessage");
async function handleAppTelemetry(request, env, headers, appAuth) {
  const data = await request.json();
  const action = data.action || "unknown";
  const details = JSON.stringify(data);
  await logActivity(env, `telemetry_${action}`, details);
  return Response.json({ success: true }, { headers });
}
__name(handleAppTelemetry, "handleAppTelemetry");
async function handleLogin(request, env, headers) {
  const adminPass = env.ADMIN_PASSWORD;
  const adminUser = env.ADMIN_USERNAME || "admin";
  if (typeof adminPass !== "string" || adminPass.length < 8) {
    return v1ConfigError(headers, "ADMIN_PASSWORD");
  }
  if (!v1JwtSecret(env)) return v1ConfigError(headers, env.AUTH_JWT_SECRET !== void 0 ? "AUTH_JWT_SECRET" : "JWT_SECRET");
  const { value: body, error } = await v1ReadJson(request, 2048);
  if (error) return Response.json({ error: "Invalid credentials" }, { status: 401, headers });
  const ip = v1ClientIp(request);
  const subject = await v1AttemptSubject("admin_login", ip);
  if (await v1RateExceeded(env, "admin_login", subject, 10, 9e5)) {
    return Response.json({ error: "Too many attempts" }, { status: 429, headers });
  }
  const username = typeof body.username === "string" ? body.username : "";
  const password = typeof body.password === "string" ? body.password : "";
  const userOk = await v1TimingSafeStrEq(username, adminUser);
  const passOk = await v1TimingSafeStrEq(password, adminPass);
  if (!userOk || !passOk) {
    return Response.json({ error: "Invalid credentials" }, { status: 401, headers });
  }
  const token = await createJWT({ user: adminUser, role: "admin", exp: Date.now() + 864e5 }, env);
  return Response.json({ token, username: adminUser }, { headers });
}
__name(handleLogin, "handleLogin");
async function createJWT(payload, env) {
  const scope = payload.role === "admin" ? "admin" : "app";
  const base = v1JwtSecret(env);
  const secret = base && env.AUTH_JWT_SECRET !== void 0 ? await hmacSign("3105-session-" + scope + "-v1", base) : base;
  if (!secret) throw new Error("JWT_SECRET no configurado");
  const header = btoa(JSON.stringify({ alg: "HS256", typ: "JWT", ...env.AUTH_JWT_SECRET !== void 0 ? { kid: scope + "-v1" } : {} }));
  const body = btoa(JSON.stringify(payload));
  const signature = await hmacSign(header + "." + body, secret);
  return header + "." + body + "." + signature;
}
__name(createJWT, "createJWT");
async function verifyAuth(request, env) {
  const authHeader = request.headers.get("Authorization");
  if (!authHeader || !authHeader.startsWith("Bearer ")) return { valid: false };
  const token = authHeader.slice(7).trim();
  const parts = token.split(".");
  if (parts.length !== 3 || !parts[0] || !parts[1] || !parts[2]) return { valid: false };
  try {
    const header = JSON.parse(atob(parts[0]));
    const payload = JSON.parse(atob(parts[1]));
    const secret = await sessionVerificationKey(env, header, payload, "admin");
    if (!secret) return { valid: false };
    if (!header || header.alg !== "HS256" || header.typ !== "JWT") return { valid: false };
    if (!payload || typeof payload.exp !== "number" || payload.exp <= Date.now()) return { valid: false };
    if (typeof payload.user !== "string" || payload.user.length === 0) return { valid: false };
    if (payload.role !== "admin" && !(header.kid === void 0 && env.ALLOW_LEGACY_ADMIN === "1" && payload.role === void 0)) return { valid: false };
    if (payload.user !== (env.ADMIN_USERNAME || "admin") || payload.userId !== void 0 || payload.licenseKey !== void 0) return { valid: false };
    const expected = await hmacSign(parts[0] + "." + parts[1], secret);
    if (!await v1TimingSafeStrEq(expected, parts[2])) return { valid: false };
    return { valid: true, user: payload.user, payload };
  } catch {
    return { valid: false };
  }
}
__name(verifyAuth, "verifyAuth");
async function hmacSign(data, secret) {
  const encoder = new TextEncoder();
  const key = await crypto.subtle.importKey(
    "raw",
    encoder.encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"]
  );
  const sig = await crypto.subtle.sign("HMAC", key, encoder.encode(data));
  return btoa(String.fromCharCode(...new Uint8Array(sig)));
}
__name(hmacSign, "hmacSign");
async function logActivity(env, action, details) {
  await env.DB.prepare(
    "INSERT INTO activity_log (action, details, created_at) VALUES (?, ?, ?)"
  ).bind(action, details, (/* @__PURE__ */ new Date()).toISOString()).run();
}
__name(logActivity, "logActivity");
async function handleDashboardStats(env, headers) {
  const users = await env.DB.prepare("SELECT COUNT(*) as count FROM users").first();
  const patches = await env.DB.prepare("SELECT COUNT(*) as count FROM patches").first();
  const activePatches = await env.DB.prepare("SELECT COUNT(*) as count FROM patches WHERE active = 1").first();
  const downloads = await env.DB.prepare("SELECT COUNT(*) as count FROM downloads").first();
  return Response.json({
    totalUsers: users.count,
    totalPatches: patches.count,
    activePatches: activePatches.count,
    totalDownloads: downloads.count
  }, { headers });
}
__name(handleDashboardStats, "handleDashboardStats");
async function handleDashboardActivity(env, headers) {
  const result = await env.DB.prepare(
    "SELECT * FROM activity_log ORDER BY created_at DESC LIMIT 10"
  ).all();
  return Response.json(result.results, { headers });
}
__name(handleDashboardActivity, "handleDashboardActivity");
async function handleGetUsers(env, headers, url) {
  const search = url.searchParams.get("search") || "";
  let query = "SELECT * FROM users";
  const params = [];
  if (search) {
    query += " WHERE username LIKE ? OR hwid LIKE ? OR license_key LIKE ?";
    const like = `%${search}%`;
    params.push(like, like, like);
  }
  query += " ORDER BY created_at DESC";
  const result = await env.DB.prepare(query).bind(...params).all();
  return Response.json(result.results, { headers });
}
__name(handleGetUsers, "handleGetUsers");
async function handleCreateUser(request, env, headers) {
  const data = await request.json();
  const id = crypto.randomUUID();
  const now = (/* @__PURE__ */ new Date()).toISOString();
  await env.DB.prepare(
    `INSERT INTO users (id, username, hwid, license_key, is_premium, is_active, is_paused, is_blocked, permissions, license_expires_at, created_at, updated_at)
     VALUES (?, ?, ?, ?, ?, 1, 0, 0, ?, ?, ?, ?)`
  ).bind(
    id,
    data.username,
    data.hwid || "",
    data.licenseKey || "",
    data.isPremium ? 1 : 0,
    data.permissions || "{}",
    data.licenseExpiresAt || null,
    now,
    now
  ).run();
  await logActivity(env, "user_created", `User ${data.username} created`);
  return Response.json({ id, ...data }, { headers });
}
__name(handleCreateUser, "handleCreateUser");
async function handleUpdateUser(id, request, env, headers) {
  const data = await request.json();
  const now = (/* @__PURE__ */ new Date()).toISOString();
  await env.DB.prepare(
    `UPDATE users SET username = ?, hwid = ?, license_key = ?, is_premium = ?, permissions = ?, updated_at = ? WHERE id = ?`
  ).bind(
    data.username,
    data.hwid || "",
    data.licenseKey || "",
    data.isPremium ? 1 : 0,
    data.permissions || "{}",
    now,
    id
  ).run();
  await logActivity(env, "user_updated", `User ${id} updated`);
  return Response.json({ success: true }, { headers });
}
__name(handleUpdateUser, "handleUpdateUser");
async function handleTogglePause(id, env, headers) {
  const user = await env.DB.prepare("SELECT is_paused, paused_at, license_expires_at, username FROM users WHERE id = ?").bind(id).first();
  if (!user) {
    return Response.json({ error: "User not found" }, { status: 404, headers });
  }
  const now = /* @__PURE__ */ new Date();
  const nowISO = now.toISOString();
  if (!user.is_paused) {
    const changed = await env.DB.prepare("UPDATE users SET is_paused = 1, paused_at = ?, updated_at = ? WHERE id = ? AND is_paused = 0").bind(nowISO, nowISO, id).run();
    if (changed.meta.changes !== 1) return Response.json({ error: "License state changed; reload" }, { status: 409, headers });
    await logActivity(env, "user_paused", `User ${user.username} license PAUSED (time frozen)`);
    return Response.json({
      is_paused: true,
      paused_at: nowISO,
      message: "License paused. Time frozen."
    }, { headers });
  } else {
    let daysToAdd = 0;
    let newExpiresAt = user.license_expires_at;
    if (user.paused_at && user.license_expires_at) {
      const pausedDate = new Date(user.paused_at);
      const millisecondsPaused = now.getTime() - pausedDate.getTime();
      daysToAdd = Math.floor(millisecondsPaused / (1e3 * 60 * 60 * 24));
      if (daysToAdd > 0) {
        const currentExpires = new Date(user.license_expires_at);
        newExpiresAt = new Date(currentExpires.getTime() + daysToAdd * 24 * 60 * 60 * 1e3).toISOString();
      }
    }
    const changed = await env.DB.prepare("UPDATE users SET is_paused = 0, paused_at = NULL, license_expires_at = ?, updated_at = ? WHERE id = ? AND is_paused = 1 AND paused_at IS ? AND license_expires_at IS ?").bind(newExpiresAt, nowISO, id, user.paused_at, user.license_expires_at).run();
    if (changed.meta.changes !== 1) return Response.json({ error: "License state changed; reload" }, { status: 409, headers });
    await logActivity(env, "user_resumed", `User ${user.username} license RESUMED (added ${daysToAdd} days, new expiry: ${newExpiresAt})`);
    return Response.json({
      is_paused: false,
      paused_at: null,
      days_added_back: daysToAdd,
      license_expires_at: newExpiresAt,
      message: `License resumed. ${daysToAdd} days added back.`
    }, { headers });
  }
}
__name(handleTogglePause, "handleTogglePause");
async function handleAdjustDays(id, request, env, headers) {
  const data = await request.json();
  const days = parseInt(data.days);
  if (isNaN(days)) {
    return Response.json({ error: "Days must be a number" }, { status: 400, headers });
  }
  const user = await env.DB.prepare("SELECT username, license_expires_at FROM users WHERE id = ?").bind(id).first();
  if (!user) {
    return Response.json({ error: "User not found" }, { status: 404, headers });
  }
  const now = /* @__PURE__ */ new Date();
  let newExpiresAt;
  if (days === 0) {
    newExpiresAt = null;
  } else if (user.license_expires_at) {
    const currentExpires = new Date(user.license_expires_at);
    newExpiresAt = new Date(currentExpires.getTime() + days * 24 * 60 * 60 * 1e3).toISOString();
  } else {
    newExpiresAt = new Date(now.getTime() + days * 24 * 60 * 60 * 1e3).toISOString();
  }
  const nowISO = now.toISOString();
  await env.DB.prepare("UPDATE users SET license_expires_at = ?, updated_at = ? WHERE id = ?").bind(newExpiresAt, nowISO, id).run();
  const action = days > 0 ? `added ${days} days` : days < 0 ? `removed ${Math.abs(days)} days` : "set to no expiration";
  await logActivity(env, "license_adjusted", `User ${user.username} license adjusted: ${action} (new expiry: ${newExpiresAt || "never"})`);
  return Response.json({
    success: true,
    license_expires_at: newExpiresAt,
    days_adjusted: days,
    message: `License ${action}`
  }, { headers });
}
__name(handleAdjustDays, "handleAdjustDays");
async function handleResetHWID(id, env, headers) {
  await env.DB.prepare("UPDATE users SET hwid = ? WHERE id = ?").bind("", id).run();
  await logActivity(env, "hwid_reset", `User ${id} HWID reset`);
  return Response.json({ success: true }, { headers });
}
__name(handleResetHWID, "handleResetHWID");
async function handleToggleBlock(id, env, headers) {
  const user = await env.DB.prepare("SELECT is_blocked FROM users WHERE id = ?").bind(id).first();
  const newState = user.is_blocked ? 0 : 1;
  await env.DB.prepare("UPDATE users SET is_blocked = ? WHERE id = ?").bind(newState, id).run();
  await logActivity(env, "user_blocked", `User ${id} ${newState ? "blocked" : "unblocked"}`);
  return Response.json({ is_blocked: newState }, { headers });
}
__name(handleToggleBlock, "handleToggleBlock");
async function handleRenewLicense(id, request, env, headers) {
  const data = await request.json();
  const days = parseInt(data.days) || 30;
  const user = await env.DB.prepare("SELECT username, license_expires_at FROM users WHERE id = ?").bind(id).first();
  if (!user) {
    return Response.json({ error: "User not found" }, { status: 404, headers });
  }
  let newExpiresAt;
  if (user.license_expires_at) {
    const existingDate = new Date(user.license_expires_at);
    const now2 = /* @__PURE__ */ new Date();
    const baseDate = existingDate > now2 ? existingDate : now2;
    newExpiresAt = new Date(baseDate.getTime() + days * 24 * 60 * 60 * 1e3).toISOString();
  } else {
    newExpiresAt = new Date(Date.now() + days * 24 * 60 * 60 * 1e3).toISOString();
  }
  const now = (/* @__PURE__ */ new Date()).toISOString();
  await env.DB.prepare("UPDATE users SET license_expires_at = ?, updated_at = ? WHERE id = ?").bind(newExpiresAt, now, id).run();
  await logActivity(env, "license_renewed", `User ${user.username} license renewed for ${days} days (expires: ${newExpiresAt})`);
  return Response.json({
    success: true,
    license_expires_at: newExpiresAt,
    days_added: days
  }, { headers });
}
__name(handleRenewLicense, "handleRenewLicense");
async function handleDeleteUser(id, env, headers) {
  const user = await env.DB.prepare("SELECT username FROM users WHERE id = ?").bind(id).first();
  if (!user) {
    return Response.json({ error: "User not found" }, { status: 404, headers });
  }
  await env.DB.prepare("DELETE FROM downloads WHERE user_id = ?").bind(id).run();
  await env.DB.prepare("DELETE FROM user_patches WHERE user_id = ?").bind(id).run();
  await env.DB.prepare("DELETE FROM users WHERE id = ?").bind(id).run();
  await logActivity(env, "user_deleted", `User ${user.username} (${id}) deleted`);
  return Response.json({ success: true }, { headers });
}
__name(handleDeleteUser, "handleDeleteUser");
async function handleGetPatches(env, headers, url) {
  const type = url.searchParams.get("type") || "";
  const active = url.searchParams.get("active") || "";
  let query = "SELECT * FROM patches";
  const conditions = [];
  const params = [];
  if (type) {
    conditions.push("type = ?");
    params.push(type);
  }
  if (active === "1") conditions.push("active = 1");
  if (conditions.length > 0) query += " WHERE " + conditions.join(" AND ");
  query += " ORDER BY created_at DESC";
  const result = await env.DB.prepare(query).bind(...params).all();
  return Response.json(result.results, { headers });
}
__name(handleGetPatches, "handleGetPatches");
async function handleCreatePatch(request, env, headers) {
  const formData = await request.formData();
  const id = crypto.randomUUID();
  const name = formData.get("name");
  const description = formData.get("description") || "";
  const version = formData.get("version") || "1.0.0";
  const type = formData.get("type") || "free";
  const password = formData.get("password") || "";
  const file = formData.get("file");
  let fileKey = "";
  if (file && file.size > 0) {
    fileKey = `${id}.3105`;
    const fileBuffer = await file.arrayBuffer();
    await env.R2.put(fileKey, fileBuffer);
  }
  try {
    const now = (/* @__PURE__ */ new Date()).toISOString();
    await env.DB.prepare(
      `INSERT INTO patches (id, name, description, version, type, file_key, content_key, password, active, created_at, updated_at)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, 1, ?, ?)`
    ).bind(id, name, description, version, type, fileKey, "", password, now, now).run();
  } catch (dbError) {
    if (fileKey) {
      try {
        await env.R2.delete(fileKey);
      } catch (e) {
        safeLog("caught-error", e);
      }
    }
    safeLog("patch-insert-failed", dbError);
    return Response.json({
      error: "Database operation failed"
    }, { status: 500, headers });
  }
  try {
    await logActivity(env, "patch_created", `Patch "${name}" created`);
  } catch (e) {
    safeLog("caught-error", e);
    safeLog("activity-log-failed", e);
  }
  return Response.json({
    id,
    name,
    version,
    type,
    hasContentKey: false,
    contentKeyExtracted: false,
    passwordSaved: !!password
  }, { headers });
}
__name(handleCreatePatch, "handleCreatePatch");
async function handleUpdatePatch(id, request, env, headers) {
  const formData = await request.formData();
  const name = formData.get("name");
  const description = formData.get("description") || "";
  const version = formData.get("version") || "1.0.0";
  const type = formData.get("type") || "free";
  const password = formData.get("password");
  const file = formData.get("file");
  let patch = await env.DB.prepare("SELECT file_key, password FROM patches WHERE id = ?").bind(id).first();
  let fileKey = patch?.file_key || "";
  let newFileKey = "";
  const effectivePassword = password !== null ? password : patch?.password || "";
  if (file && file.size > 0) {
    newFileKey = `${id}.3105`;
    const fileBuffer = await file.arrayBuffer();
    await env.R2.put(newFileKey, fileBuffer);
    fileKey = newFileKey;
  }
  try {
    const now = (/* @__PURE__ */ new Date()).toISOString();
    await env.DB.prepare(
      `UPDATE patches SET name = ?, description = ?, version = ?, type = ?, file_key = ?, password = ?, updated_at = ? WHERE id = ?`
    ).bind(name, description, version, type, fileKey, effectivePassword, now, id).run();
  } catch (dbError) {
    if (newFileKey) {
      try {
        await env.R2.delete(newFileKey);
      } catch (e) {
        safeLog("caught-error", e);
      }
    }
    safeLog("patch-update-failed", dbError);
    return Response.json({
      error: "Database operation failed"
    }, { status: 500, headers });
  }
  if (newFileKey && patch.file_key && patch.file_key !== newFileKey) {
    try {
      await env.R2.delete(patch.file_key);
    } catch (e) {
      safeLog("caught-error", e);
    }
  }
  try {
    await logActivity(env, "patch_updated", `Patch ${id} updated`);
  } catch (e) {
    safeLog("caught-error", e);
    safeLog("activity-log-failed", e);
  }
  return Response.json({
    success: true,
    hasContentKey: false,
    contentKeyExtracted: false,
    passwordSaved: !!effectivePassword
  }, { headers });
}
__name(handleUpdatePatch, "handleUpdatePatch");
async function handleDeletePatch(id, env, headers) {
  const patch = await env.DB.prepare("SELECT file_key, name FROM patches WHERE id = ?").bind(id).first();
  try {
    await env.DB.prepare("DELETE FROM downloads WHERE patch_id = ?").bind(id).run();
    await env.DB.prepare("DELETE FROM user_patches WHERE patch_id = ?").bind(id).run();
    await env.DB.prepare("DELETE FROM patches WHERE id = ?").bind(id).run();
  } catch (dbError) {
    safeLog("patch-delete-failed", dbError);
    return Response.json({
      error: "Database operation failed"
    }, { status: 500, headers });
  }
  if (patch?.file_key) {
    try {
      await env.R2.delete(patch.file_key);
    } catch (e) {
      safeLog("caught-error", e);
    }
  }
  try {
    await logActivity(env, "patch_deleted", `Patch "${patch?.name || id}" deleted`);
  } catch (e) {
    safeLog("caught-error", e);
    safeLog("activity-log-failed", e);
  }
  return Response.json({ success: true }, { headers });
}
__name(handleDeletePatch, "handleDeletePatch");
async function handleTogglePatch(id, env, headers) {
  const patch = await env.DB.prepare("SELECT active FROM patches WHERE id = ?").bind(id).first();
  const newState = patch.active ? 0 : 1;
  await env.DB.prepare("UPDATE patches SET active = ? WHERE id = ?").bind(newState, id).run();
  await logActivity(env, "patch_toggled", `Patch ${id} ${newState ? "activated" : "deactivated"}`);
  return Response.json({ active: newState }, { headers });
}
__name(handleTogglePatch, "handleTogglePatch");
async function handleGetAccess(env, headers) {
  const result = await env.DB.prepare(
    `SELECT up.*, u.username, p.name as patch_name 
     FROM user_patches up 
     JOIN users u ON up.user_id = u.id 
     JOIN patches p ON up.patch_id = p.id 
     ORDER BY up.created_at DESC`
  ).all();
  return Response.json(result.results, { headers });
}
__name(handleGetAccess, "handleGetAccess");
async function handleGrantAccess(request, env, headers) {
  const { userId, patchId } = await request.json();
  const now = (/* @__PURE__ */ new Date()).toISOString();
  await env.DB.prepare(
    "INSERT OR IGNORE INTO user_patches (user_id, patch_id, created_at) VALUES (?, ?, ?)"
  ).bind(userId, patchId, now).run();
  await logActivity(env, "access_granted", `Access granted: user ${userId} -> patch ${patchId}`);
  return Response.json({ success: true }, { headers });
}
__name(handleGrantAccess, "handleGrantAccess");
async function handleRevokeAccess(request, env, headers) {
  const { userId, patchId } = await request.json();
  await env.DB.prepare(
    "DELETE FROM user_patches WHERE user_id = ? AND patch_id = ?"
  ).bind(userId, patchId).run();
  await logActivity(env, "access_revoked", `Access revoked: user ${userId} -> patch ${patchId}`);
  return Response.json({ success: true }, { headers });
}
__name(handleRevokeAccess, "handleRevokeAccess");
async function handleGetMessages(env, headers) {
  const result = await env.DB.prepare("SELECT * FROM messages ORDER BY created_at DESC").all();
  return Response.json(result.results, { headers });
}
__name(handleGetMessages, "handleGetMessages");
async function handleCreateMessage(request, env, headers) {
  const data = await request.json();
  const id = crypto.randomUUID();
  const now = (/* @__PURE__ */ new Date()).toISOString();
  await env.DB.prepare(
    `INSERT INTO messages (id, title, content, type, target_hwid, active, created_at, updated_at)
     VALUES (?, ?, ?, ?, ?, 1, ?, ?)`
  ).bind(id, data.title, data.content, data.type || "info", data.targetHwid || null, now, now).run();
  await logActivity(env, "message_created", `Message "${data.title}" created`);
  return Response.json({ id }, { headers });
}
__name(handleCreateMessage, "handleCreateMessage");
async function handleUpdateMessage(id, request, env, headers) {
  const data = await request.json();
  const now = (/* @__PURE__ */ new Date()).toISOString();
  await env.DB.prepare(
    `UPDATE messages SET title = ?, content = ?, type = ?, target_hwid = ?, updated_at = ? WHERE id = ?`
  ).bind(data.title, data.content, data.type, data.targetHwid || null, now, id).run();
  return Response.json({ success: true }, { headers });
}
__name(handleUpdateMessage, "handleUpdateMessage");
async function handleDeleteMessage(id, env, headers) {
  await env.DB.prepare("DELETE FROM messages WHERE id = ?").bind(id).run();
  await logActivity(env, "message_deleted", `Message ${id} deleted`);
  return Response.json({ success: true }, { headers });
}
__name(handleDeleteMessage, "handleDeleteMessage");
async function handleToggleMessage(id, env, headers) {
  const msg = await env.DB.prepare("SELECT active FROM messages WHERE id = ?").bind(id).first();
  const newState = msg.active ? 0 : 1;
  await env.DB.prepare("UPDATE messages SET active = ? WHERE id = ?").bind(newState, id).run();
  return Response.json({ active: newState }, { headers });
}
__name(handleToggleMessage, "handleToggleMessage");
async function handleStats(env, headers, url) {
  const type = url.searchParams.get("type") || "all";
  if (type === "downloads") {
    const result = await env.DB.prepare(
      `SELECT DATE(created_at) as date, COUNT(*) as count 
       FROM downloads 
       WHERE created_at > datetime('now', '-30 days')
       GROUP BY DATE(created_at) ORDER BY date`
    ).all();
    return Response.json(result.results, { headers });
  }
  if (type === "popular") {
    const result = await env.DB.prepare(
      `SELECT p.name, COUNT(d.id) as downloads 
       FROM downloads d JOIN patches p ON d.patch_id = p.id 
       GROUP BY d.patch_id ORDER BY downloads DESC LIMIT 10`
    ).all();
    return Response.json(result.results, { headers });
  }
  const users = await env.DB.prepare("SELECT COUNT(*) as count FROM users").first();
  const patches = await env.DB.prepare("SELECT COUNT(*) as count FROM patches").first();
  const downloads = await env.DB.prepare("SELECT COUNT(*) as count FROM downloads").first();
  const todayDownloads = await env.DB.prepare(
    "SELECT COUNT(*) as count FROM downloads WHERE DATE(created_at) = DATE('now')"
  ).first();
  return Response.json({
    totalUsers: users.count,
    totalPatches: patches.count,
    totalDownloads: downloads.count,
    todayDownloads: todayDownloads.count
  }, { headers });
}
__name(handleStats, "handleStats");
async function handleGetActivity(env, headers, url) {
  const limit = parseInt(url.searchParams.get("limit") || "50");
  const result = await env.DB.prepare(
    "SELECT * FROM activity_log ORDER BY created_at DESC LIMIT ?"
  ).bind(limit).all();
  return Response.json(result.results, { headers });
}
__name(handleGetActivity, "handleGetActivity");
async function handleGetConfig(env, headers) {
  const result = await env.DB.prepare("SELECT * FROM config ORDER BY key").all();
  const config = {};
  result.results.forEach((r) => {
    config[r.key] = r.value;
  });
  return Response.json(config, { headers });
}
__name(handleGetConfig, "handleGetConfig");
async function handleUpdateConfig(request, env, headers) {
  const data = await request.json();
  const now = (/* @__PURE__ */ new Date()).toISOString();
  for (const [key, value] of Object.entries(data)) {
    await env.DB.prepare(
      `INSERT INTO config (key, value, updated_at) VALUES (?, ?, ?)
       ON CONFLICT(key) DO UPDATE SET value = ?, updated_at = ?`
    ).bind(key, value, now, value, now).run();
  }
  await logActivity(env, "config_updated", "Configuration updated");
  return Response.json({ success: true }, { headers });
}
__name(handleUpdateConfig, "handleUpdateConfig");
var V1_LEASE_CONTEXT = "3105-lease-v1";
var V1_CHALLENGE_TTL_MS = 5 * 60 * 1e3;
var V1_MAX_BODY_BYTES = 8192;
var V1_UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
var V1_P256_SPKI_PREFIX = Uint8Array.from([
  48,
  89,
  48,
  19,
  6,
  7,
  42,
  134,
  72,
  206,
  61,
  2,
  1,
  6,
  8,
  42,
  134,
  72,
  206,
  61,
  3,
  1,
  7,
  3,
  66,
  0
]);
function v1NowIso() {
  return (/* @__PURE__ */ new Date()).toISOString();
}
__name(v1NowIso, "v1NowIso");
function v1B64Encode(bytes) {
  const u8 = bytes instanceof Uint8Array ? bytes : new Uint8Array(bytes);
  let s = "";
  for (let i = 0; i < u8.length; i++) s += String.fromCharCode(u8[i]);
  return btoa(s);
}
__name(v1B64Encode, "v1B64Encode");
function v1B64Decode(text) {
  const bin = atob(String(text));
  const out = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i);
  return out;
}
__name(v1B64Decode, "v1B64Decode");
function v1TextBytes(text) {
  return new TextEncoder().encode(text);
}
__name(v1TextBytes, "v1TextBytes");
function v1ClientIp(request) {
  return request.headers.get("CF-Connecting-IP") || request.headers.get("X-Forwarded-For") || "unknown";
}
__name(v1ClientIp, "v1ClientIp");
async function v1ReadJson(request, maxBytes = V1_MAX_BODY_BYTES) {
  let text;
  try {
    text = await request.text();
  } catch {
    return { error: "invalid" };
  }
  if (typeof text !== "string" || text.length === 0) return { error: "invalid" };
  if (text.length > maxBytes) return { error: "tooLarge" };
  let value;
  try {
    value = JSON.parse(text);
  } catch {
    return { error: "invalid" };
  }
  if (value === null || typeof value !== "object" || Array.isArray(value)) {
    return { error: "invalid" };
  }
  return { value };
}
__name(v1ReadJson, "v1ReadJson");
function v1SafeString(value, min, max, pattern) {
  if (typeof value !== "string") return null;
  const s = value.trim();
  if (s.length < min || s.length > max) return null;
  if (pattern && !pattern.test(s)) return null;
  return s;
}
__name(v1SafeString, "v1SafeString");
async function v1TimingSafeStrEq(a, b) {
  if (typeof a !== "string" || typeof b !== "string") return false;
  const enc = new TextEncoder();
  const [ha, hb] = await Promise.all([
    crypto.subtle.digest("SHA-256", enc.encode(a)),
    crypto.subtle.digest("SHA-256", enc.encode(b))
  ]);
  const ua = new Uint8Array(ha);
  const ub = new Uint8Array(hb);
  let diff = ua.length ^ ub.length;
  for (let i = 0; i < ua.length; i++) diff |= ua[i] ^ ub[i];
  return diff === 0;
}
__name(v1TimingSafeStrEq, "v1TimingSafeStrEq");
async function v1AttemptSubject(...parts) {
  const data = v1TextBytes(parts.join("|"));
  const digest = new Uint8Array(await crypto.subtle.digest("SHA-256", data));
  return v1B64Encode(digest);
}
__name(v1AttemptSubject, "v1AttemptSubject");
async function v1RateExceeded(env, scope, subject, limit, windowMs) {
  try {
    const result = await env.DB.prepare(`
      INSERT INTO license_attempts (scope, subject, created_at)
      SELECT ?, ?, ? WHERE (
        SELECT COUNT(*) FROM license_attempts
        WHERE scope = ? AND subject = ? AND created_at > ?
      ) < ?
    `).bind(scope, subject, Date.now(), scope, subject, Date.now() - windowMs, limit).run();
    if (!result || result.success === false || !result.meta || ![0, 1].includes(result.meta.changes)) throw new Error("Invalid D1 result");
    return result.meta.changes === 0;
  } catch (error) {
    safeLog("rate-limit-unavailable", error);
    throw new RateLimitUnavailable();
  }
}
__name(v1RateExceeded, "v1RateExceeded");
async function sessionVerificationKey(env, header, payload, scope) {
  if (!header || !payload) return null;
  if (header.kid !== void 0) {
    if (header.kid !== scope + "-v1" || env.AUTH_JWT_SECRET === void 0) return null;
    const base = v1JwtSecret(env);
    return base ? hmacSign("3105-session-" + scope + "-v1", base) : null;
  }
  const old = env.JWT_SECRET;
  if (typeof old !== "string" || old.length < 32) return null;
  if (env.AUTH_JWT_SECRET !== void 0) {
    const cutoff = Number(env.LEGACY_JWT_ACCEPT_UNTIL_MS);
    if (!Number.isFinite(cutoff) || cutoff <= Date.now() || cutoff > Date.now() + 864e5 || typeof payload.exp !== "number" || payload.exp > cutoff) return null;
  }
  return old;
}
__name(sessionVerificationKey, "sessionVerificationKey");
function v1JwtSecret(env) {
  const s = env.AUTH_JWT_SECRET !== void 0 ? env.AUTH_JWT_SECRET : env.JWT_SECRET;
  if (typeof s !== "string" || s.length < 32) return null;
  return s;
}
__name(v1JwtSecret, "v1JwtSecret");
function v1ConfigError(headers, what) {
  console.error("configuracion incompleta:", what);
  return Response.json({ error: "Authentication service unavailable", code: "AUTH_UNAVAILABLE" }, { status: 503, headers });
}
__name(v1ConfigError, "v1ConfigError");
function v1Error(headers, error, status = 200) {
  return Response.json({ error }, { status, headers });
}
__name(v1Error, "v1Error");
var v1CachedSeedRaw = null;
var v1CachedSeed = null;
function v1SigningSeed(env) {
  const raw = env.LEASE_SIGNING_KEY;
  if (!raw) throw new Error("LEASE_SIGNING_KEY no esta configurada");
  const rawText = String(raw).trim();
  if (v1CachedSeedRaw === rawText) return v1CachedSeed;
  let key;
  try {
    key = v1B64Decode(rawText);
  } catch {
    throw new Error("LEASE_SIGNING_KEY no es base64 valido");
  }
  if (key.length === 48 && key[0] === 48) key = key.slice(key.length - 32);
  if (key.length !== 32) {
    throw new Error("LEASE_SIGNING_KEY debe ser PKCS#8 (48 B) o semilla (32 B) en base64");
  }
  v1CachedSeedRaw = rawText;
  v1CachedSeed = key;
  return key;
}
__name(v1SigningSeed, "v1SigningSeed");
async function v1KidFromPublicKey(publicKeyB64) {
  const raw = v1B64Decode(publicKeyB64);
  return v1B64Encode(await crypto.subtle.digest("SHA-256", raw));
}
__name(v1KidFromPublicKey, "v1KidFromPublicKey");
async function v1ValidP256PublicKey(publicKeyB64) {
  try {
    if (typeof publicKeyB64 !== "string" || publicKeyB64.length > 128) return false;
    const raw = v1B64Decode(publicKeyB64);
    if (raw.length !== 65 || raw[0] !== 4) return false;
    const spki = new Uint8Array(V1_P256_SPKI_PREFIX.length + raw.length);
    spki.set(V1_P256_SPKI_PREFIX, 0);
    spki.set(raw, V1_P256_SPKI_PREFIX.length);
    await crypto.subtle.importKey("spki", spki, { name: "ECDSA", namedCurve: "P-256" }, false, ["verify"]);
    return true;
  } catch {
    return false;
  }
}
__name(v1ValidP256PublicKey, "v1ValidP256PublicKey");
function v1DerToRawSignature(sig) {
  if (sig.length === 64) return sig;
  let i = 0;
  if (sig[i++] !== 48) return null;
  let len = sig[i++];
  if (len & 128) {
    const n = len & 127;
    if (n === 0 || n > 2) return null;
    len = 0;
    for (let j = 0; j < n; j++) len = len << 8 | sig[i++];
  }
  if (i + len > sig.length) return null;
  const readInt = /* @__PURE__ */ __name(() => {
    if (sig[i++] !== 2) return null;
    let l = sig[i++];
    if (l & 128) {
      const n = l & 127;
      if (n === 0 || n > 2) return null;
      l = 0;
      for (let j = 0; j < n; j++) l = l << 8 | sig[i++];
    }
    if (l <= 0 || i + l > sig.length) return null;
    let v = sig.slice(i, i + l);
    i += l;
    while (v.length > 1 && v[0] === 0) v = v.slice(1);
    if (v.length > 32) return null;
    return v;
  }, "readInt");
  const r = readInt();
  const s = readInt();
  if (!r || !s) return null;
  const out = new Uint8Array(64);
  out.set(r, 32 - r.length);
  out.set(s, 64 - s.length);
  return out;
}
__name(v1DerToRawSignature, "v1DerToRawSignature");
async function v1VerifyDeviceSignature(publicKeyB64, messageBytes, signatureB64) {
  try {
    if (typeof signatureB64 !== "string" || signatureB64.length > 600) return false;
    if (!await v1ValidP256PublicKey(publicKeyB64)) return false;
    const raw = v1B64Decode(publicKeyB64);
    const sig = v1B64Decode(signatureB64);
    const sigRaw = v1DerToRawSignature(sig);
    if (!sigRaw) return false;
    const spki = new Uint8Array(V1_P256_SPKI_PREFIX.length + raw.length);
    spki.set(V1_P256_SPKI_PREFIX, 0);
    spki.set(raw, V1_P256_SPKI_PREFIX.length);
    const key = await crypto.subtle.importKey(
      "spki",
      spki,
      { name: "ECDSA", namedCurve: "P-256" },
      false,
      ["verify"]
    );
    return await crypto.subtle.verify(
      { name: "ECDSA", hash: "SHA-256" },
      key,
      sigRaw,
      messageBytes
    );
  } catch {
    return false;
  }
}
__name(v1VerifyDeviceSignature, "v1VerifyDeviceSignature");
function v1LeaseTtl(env) {
  const ttl = parseInt(env.LEASE_TTL_SECONDS || "86400", 10);
  if (!Number.isFinite(ttl) || ttl < 300) return 86400;
  if (ttl > 2592e3) return 2592e3;
  return ttl;
}
__name(v1LeaseTtl, "v1LeaseTtl");
async function v1IssueLease(env, activation, nowSeconds) {
  const seed = v1SigningSeed(env);
  const payload = {
    v: 1,
    aid: activation.id,
    kid: activation.kid,
    iat: nowSeconds,
    exp: nowSeconds + v1LeaseTtl(env),
    caps: []
  };
  const leaseJson = JSON.stringify(payload);
  const leaseBytes = v1TextBytes(leaseJson);
  const message = new Uint8Array(V1_LEASE_CONTEXT.length + leaseBytes.length);
  message.set(v1TextBytes(V1_LEASE_CONTEXT), 0);
  message.set(leaseBytes, V1_LEASE_CONTEXT.length);
  const signature = await v1Ed25519Sign(seed, message);
  return {
    status: "ACTIVE",
    lease: v1B64Encode(leaseBytes),
    leaseSignature: v1B64Encode(signature)
  };
}
__name(v1IssueLease, "v1IssueLease");
async function v1LoadActivation(env, activationId) {
  if (!V1_UUID_RE.test(activationId)) return null;
  return await env.DB.prepare("SELECT * FROM device_activations WHERE id = ?").bind(activationId).first();
}
__name(v1LoadActivation, "v1LoadActivation");
async function v1UserBlockedReason(env, userId) {
  const user = await env.DB.prepare("SELECT * FROM users WHERE id = ?").bind(userId).first();
  if (!user) return "revoked";
  if (user.is_blocked) return "deviceBlocked";
  if (!user.is_active || user.is_paused) return "revoked";
  if (user.license_expires_at && (!Number.isFinite(Date.parse(user.license_expires_at)) || Date.parse(user.license_expires_at) <= Date.now())) return "revoked";
  return null;
}
__name(v1UserBlockedReason, "v1UserBlockedReason");
async function handleV1DeviceCheck(request, env, headers) {
  try {
    const { value: body } = await v1ReadJson(request, 2048);
    const deviceId = v1SafeString(body && body.deviceId, 8, 128, /^[A-Za-z0-9._:-]+$/);
    if (!deviceId) return Response.json({ blocked: false }, { headers });
    let blocked = false;
    const row = await env.DB.prepare("SELECT device_id FROM blocked_devices WHERE device_id = ?").bind(deviceId).first();
    if (row) blocked = true;
    if (!blocked) {
      const cfg = await env.DB.prepare("SELECT value FROM config WHERE key = 'global_block'").first();
      if (cfg && cfg.value === "1") blocked = true;
    }
    try {
      const now = v1NowIso();
      await env.DB.prepare(`INSERT INTO device_seen (device_id, first_seen, last_seen)
                  VALUES (?, ?, ?)
                  ON CONFLICT(device_id) DO UPDATE SET last_seen = excluded.last_seen`).bind(deviceId, now, now).run();
    } catch (e) {
      safeLog("caught-error", e);
      safeLog("device_seen:", e);
    }
    return Response.json({ blocked }, { headers });
  } catch (e) {
    safeLog("caught-error", e);
    safeLog("device-check:", e);
    return Response.json({ blocked: false }, { headers });
  }
}
__name(handleV1DeviceCheck, "handleV1DeviceCheck");
async function handleV1Activation(request, env, headers) {
  const { value: body } = await v1ReadJson(request, 4096);
  const key = v1SafeString(body && body.key, 4, 200, /^[\x21-\x7e]+$/);
  const publicKey = typeof (body && body.publicKey) === "string" ? body.publicKey.trim() : "";
  if (!key) return v1Error(headers, "invalidKey");
  if (!publicKey || !await v1ValidP256PublicKey(publicKey)) {
    return v1Error(headers, "missingDeviceKey");
  }
  const subject = await v1AttemptSubject("activation", key, v1ClientIp(request));
  if (await v1RateExceeded(env, "activation", subject, 15, 6e5)) {
    return Response.json({ error: "rateLimited" }, { status: 429, headers });
  }
  const user = await env.DB.prepare("SELECT * FROM users WHERE license_key = ?").bind(key).first();
  if (!user) {
    return v1Error(headers, "invalidKey");
  }
  if (user.is_blocked) return v1Error(headers, "deviceBlocked");
  if (!user.is_active || user.is_paused) return v1Error(headers, "revoked");
  if (user.license_expires_at && (!Number.isFinite(Date.parse(user.license_expires_at)) || Date.parse(user.license_expires_at) <= Date.now())) {
    return v1Error(headers, "revoked");
  }
  const kid = await v1KidFromPublicKey(publicKey);
  const { results } = await env.DB.prepare("SELECT * FROM device_activations WHERE license_key = ?").bind(key).all();
  const rows = results || [];
  const same = rows.find((r) => r.kid === kid);
  if (same) {
    if (same.status !== "active") return v1Error(headers, "revoked");
    await env.DB.prepare("UPDATE device_activations SET last_seen_at = ? WHERE id = ?").bind(v1NowIso(), same.id).run();
    return Response.json({ activationId: same.id }, { headers });
  }
  const maxDevices = Math.min(Math.max(parseInt(env.LICENSE_MAX_DEVICES || "1", 10) || 1, 1), 50);
  const activeCount = rows.filter((r) => r.status === "active").length;
  if (activeCount >= maxDevices) return v1Error(headers, "alreadyBound");
  const id = crypto.randomUUID();
  const now = v1NowIso();
  await env.DB.prepare(`INSERT INTO device_activations
              (id, license_key, user_id, public_key, kid, status, created_at, last_seen_at)
              VALUES (?, ?, ?, ?, ?, 'active', ?, ?)`).bind(id, key, user.id, publicKey, kid, now, now).run();
  await logActivity(env, "license_activation", `Activacion ${id} para ${user.username}`);
  return Response.json({ activationId: id }, { headers });
}
__name(handleV1Activation, "handleV1Activation");
async function handleV1Challenge(request, env, headers) {
  const { value: body } = await v1ReadJson(request, 2048);
  const activationId = v1SafeString(body && body.activationId, 36, 36, V1_UUID_RE);
  if (!activationId) return v1Error(headers, "revoked");
  const activation = await v1LoadActivation(env, activationId);
  if (!activation || activation.status !== "active") return v1Error(headers, "revoked");
  const reason = await v1UserBlockedReason(env, activation.user_id);
  if (reason) return v1Error(headers, reason);
  const subject = await v1AttemptSubject("challenge", activation.id, v1ClientIp(request));
  if (await v1RateExceeded(env, "challenge", subject, 30, 6e5)) {
    return Response.json({ error: "rateLimited" }, { status: 429, headers });
  }
  const nonce = v1B64Encode(crypto.getRandomValues(new Uint8Array(32)));
  const id = crypto.randomUUID();
  const now = v1NowIso();
  const expires = new Date(Date.now() + V1_CHALLENGE_TTL_MS).toISOString();
  await env.DB.prepare(`INSERT INTO device_challenges
              (id, activation_id, nonce, created_at, expires_at, used)
              VALUES (?, ?, ?, ?, ?, 0)`).bind(id, activation.id, nonce, now, expires).run();
  if (Math.random() < 0.05) {
    await env.DB.prepare("DELETE FROM device_challenges WHERE expires_at < ?").bind(new Date(Date.now() - 864e5).toISOString()).run();
  }
  await env.DB.prepare("UPDATE device_activations SET last_seen_at = ? WHERE id = ?").bind(now, activation.id).run();
  return Response.json({ challengeId: id, nonce }, { headers });
}
__name(handleV1Challenge, "handleV1Challenge");
async function handleV1Verification(request, env, headers) {
  const rejected = /* @__PURE__ */ __name((error = "revoked") => Response.json({ status: "REJECTED", error }, { headers }), "rejected");
  const { value: body } = await v1ReadJson(request, 4096);
  const activationId = v1SafeString(body && body.activationId, 36, 36, V1_UUID_RE);
  const challengeId = v1SafeString(body && body.challengeId, 36, 36, V1_UUID_RE);
  const signature = v1SafeString(body && body.signature, 64, 600, /^[A-Za-z0-9+/=]+$/);
  if (!activationId || !challengeId || !signature) return rejected();
  const activation = await v1LoadActivation(env, activationId);
  if (!activation || activation.status !== "active") return rejected();
  const reason = await v1UserBlockedReason(env, activation.user_id);
  if (reason) return rejected(reason);
  const subject = await v1AttemptSubject("verification", activation.id, v1ClientIp(request));
  if (await v1RateExceeded(env, "verification", subject, 20, 6e5)) {
    return Response.json({ status: "REJECTED", error: "rateLimited" }, { status: 429, headers });
  }
  const challenge = await env.DB.prepare("SELECT * FROM device_challenges WHERE id = ?").bind(challengeId).first();
  if (!challenge || challenge.activation_id !== activation.id) return rejected();
  const claim = await env.DB.prepare(`UPDATE device_challenges SET used = 1
              WHERE id = ? AND activation_id = ? AND used = 0 AND expires_at > ?`).bind(challenge.id, activation.id, v1NowIso()).run();
  const changes = claim && claim.meta ? Number(claim.meta.changes || 0) : 0;
  if (changes !== 1) {
    return rejected("nonceUsed");
  }
  const nonceBytes = v1B64Decode(challenge.nonce);
  const valid = await v1VerifyDeviceSignature(activation.public_key, nonceBytes, signature);
  if (!valid) {
    return rejected("invalidSignature");
  }
  const nowSeconds = Math.floor(Date.now() / 1e3);
  let reply;
  try {
    reply = await v1IssueLease(env, activation, nowSeconds);
  } catch (e) {
    safeLog("caught-error", e);
    safeLog("lease signing:", e);
    return Response.json({ status: "REJECTED", error: "network" }, { status: 500, headers });
  }
  await env.DB.prepare("UPDATE device_activations SET last_lease_at = ?, last_seen_at = ? WHERE id = ?").bind(v1NowIso(), v1NowIso(), activation.id).run();
  return Response.json(reply, { headers });
}
__name(handleV1Verification, "handleV1Verification");
async function handleV1Telemetry(request, env, headers) {
  try {
    const text = await request.text();
    if (typeof text === "string" && text.length > 16384) {
      return Response.json({ error: "tooLarge" }, { status: 413, headers });
    }
  } catch {
  }
  return Response.json({ ok: true }, { headers });
}
__name(handleV1Telemetry, "handleV1Telemetry");
async function handleLicListDevices(env, headers) {
  const { results } = await env.DB.prepare(`
    SELECT d.device_id, d.first_seen, d.last_seen,
           CASE WHEN b.device_id IS NULL THEN 0 ELSE 1 END AS blocked,
           b.reason AS block_reason
    FROM device_seen d
    LEFT JOIN blocked_devices b ON b.device_id = d.device_id
    ORDER BY d.last_seen DESC
    LIMIT 500
  `).all();
  return Response.json({ devices: results || [] }, { headers });
}
__name(handleLicListDevices, "handleLicListDevices");
async function handleLicListActivations(env, headers) {
  const { results } = await env.DB.prepare(`
    SELECT a.id, a.license_key, a.user_id, u.username, a.public_key, a.kid,
           a.status, a.created_at, a.last_seen_at, a.last_lease_at
    FROM device_activations a
    LEFT JOIN users u ON u.id = a.user_id
    ORDER BY a.created_at DESC
  `).all();
  return Response.json({ activations: results || [] }, { headers });
}
__name(handleLicListActivations, "handleLicListActivations");
async function handleLicDeleteActivation(id, env, headers) {
  if (!V1_UUID_RE.test(id)) return Response.json({ error: "invalid id" }, { status: 400, headers });
  await env.DB.prepare("DELETE FROM device_challenges WHERE activation_id = ?").bind(id).run();
  await env.DB.prepare("DELETE FROM device_activations WHERE id = ?").bind(id).run();
  await logActivity(env, "license_activation_deleted", `Activacion ${id} eliminada`);
  return Response.json({ ok: true }, { headers });
}
__name(handleLicDeleteActivation, "handleLicDeleteActivation");
async function handleLicListBlocked(env, headers) {
  const { results } = await env.DB.prepare("SELECT device_id, reason, created_at FROM blocked_devices ORDER BY created_at DESC").all();
  return Response.json({ blocked: results || [] }, { headers });
}
__name(handleLicListBlocked, "handleLicListBlocked");
async function handleLicBlockDevice(request, env, headers) {
  const { value: body } = await v1ReadJson(request, 2048);
  const deviceId = v1SafeString(body && body.deviceId, 8, 128, /^[A-Za-z0-9._:-]+$/);
  if (!deviceId) return Response.json({ error: "deviceId required" }, { status: 400, headers });
  const reason = v1SafeString(body && body.reason, 0, 200) || "";
  await env.DB.prepare("INSERT OR REPLACE INTO blocked_devices (device_id, reason, created_at) VALUES (?, ?, ?)").bind(deviceId, reason, v1NowIso()).run();
  await logActivity(env, "license_device_blocked", `Dispositivo ${deviceId} bloqueado`);
  return Response.json({ ok: true }, { headers });
}
__name(handleLicBlockDevice, "handleLicBlockDevice");
async function handleLicUnblockDevice(deviceId, env, headers) {
  if (!v1SafeString(deviceId, 8, 128, /^[A-Za-z0-9._:-]+$/)) {
    return Response.json({ error: "invalid id" }, { status: 400, headers });
  }
  await env.DB.prepare("DELETE FROM blocked_devices WHERE device_id = ?").bind(deviceId).run();
  await logActivity(env, "license_device_unblocked", `Dispositivo ${deviceId} desbloqueado`);
  return Response.json({ ok: true }, { headers });
}
__name(handleLicUnblockDevice, "handleLicUnblockDevice");
async function handleLicSigningKey(env, headers) {
  try {
    const seed = v1SigningSeed(env);
    const pub = await v1Ed25519PublicKeyFromSeed(seed);
    return Response.json({
      algorithm: "Ed25519",
      publicKeyBase64: v1B64Encode(pub),
      publicKeyHex: toHex(pub),
      fingerprintSha256: toHex(new Uint8Array(await crypto.subtle.digest("SHA-256", pub)))
    }, { headers });
  } catch (e) {
    safeLog("caught-error", e);
    safeLog("signing-key:", e);
    return Response.json({ error: "Authentication service unavailable", code: "AUTH_UNAVAILABLE" }, { status: 503, headers });
  }
}
__name(handleLicSigningKey, "handleLicSigningKey");
var V1_ED_P = 2n ** 255n - 19n;
var V1_ED_L = 2n ** 252n + 27742317777372353535851937790883648493n;
function v1EdMod(a) {
  const r = a % V1_ED_P;
  return r >= 0n ? r : r + V1_ED_P;
}
__name(v1EdMod, "v1EdMod");
function v1EdModL(a) {
  const r = a % V1_ED_L;
  return r >= 0n ? r : r + V1_ED_L;
}
__name(v1EdModL, "v1EdModL");
function v1EdPow(b, e) {
  let r = 1n;
  b = v1EdMod(b);
  while (e > 0n) {
    if (e & 1n) r = r * b % V1_ED_P;
    b = b * b % V1_ED_P;
    e >>= 1n;
  }
  return r;
}
__name(v1EdPow, "v1EdPow");
var V1_ED_D = v1EdMod(-121665n * v1EdPow(121666n, V1_ED_P - 2n));
var V1_ED_D2 = v1EdMod(2n * V1_ED_D);
var V1_ED_BX = 15112221349535400772501151409588531511454012693041857206046113283949847762202n;
var V1_ED_BY = 46316835694926478169428394003475163141307993866256225615783033603165251855960n;
var V1_ED_BASE = { X: V1_ED_BX, Y: V1_ED_BY, Z: 1n, T: v1EdMod(V1_ED_BX * V1_ED_BY) };
function v1EdAdd(p, q) {
  const a = v1EdMod((p.Y - p.X) * (q.Y - q.X));
  const b = v1EdMod((p.Y + p.X) * (q.Y + q.X));
  const c = v1EdMod(p.T * V1_ED_D2 * q.T);
  const d = v1EdMod(p.Z * 2n * q.Z);
  const e = v1EdMod(b - a);
  const f = v1EdMod(d - c);
  const g = v1EdMod(d + c);
  const h = v1EdMod(b + a);
  return { X: v1EdMod(e * f), Y: v1EdMod(g * h), T: v1EdMod(e * h), Z: v1EdMod(f * g) };
}
__name(v1EdAdd, "v1EdAdd");
function v1EdMul(s, p) {
  let q = { X: 0n, Y: 1n, Z: 1n, T: 0n };
  while (s > 0n) {
    if (s & 1n) q = v1EdAdd(q, p);
    p = v1EdAdd(p, p);
    s >>= 1n;
  }
  return q;
}
__name(v1EdMul, "v1EdMul");
function v1EdEncode(p) {
  const zi = v1EdPow(p.Z, V1_ED_P - 2n);
  const x = v1EdMod(p.X * zi);
  const y = v1EdMod(p.Y * zi);
  const out = new Uint8Array(32);
  let v = y;
  for (let i = 0; i < 32; i++) {
    out[i] = Number(v & 0xffn);
    v >>= 8n;
  }
  out[31] |= Number((x & 1n) << 7n);
  return out;
}
__name(v1EdEncode, "v1EdEncode");
function v1EdLeToBig(bytes, len) {
  let v = 0n;
  for (let i = len - 1; i >= 0; i--) v = v << 8n | BigInt(bytes[i]);
  return v;
}
__name(v1EdLeToBig, "v1EdLeToBig");
function v1EdBigToLe32(v) {
  const out = new Uint8Array(32);
  for (let i = 0; i < 32; i++) {
    out[i] = Number(v & 0xffn);
    v >>= 8n;
  }
  return out;
}
__name(v1EdBigToLe32, "v1EdBigToLe32");
async function v1Sha512(...parts) {
  const total = parts.reduce((n, p) => n + p.length, 0);
  const buf = new Uint8Array(total);
  let o = 0;
  for (const p of parts) {
    buf.set(p, o);
    o += p.length;
  }
  return new Uint8Array(await crypto.subtle.digest("SHA-512", buf));
}
__name(v1Sha512, "v1Sha512");
function v1EdClamp(h) {
  const a = h.slice(0, 32);
  a[0] &= 248;
  a[31] &= 127;
  a[31] |= 64;
  return a;
}
__name(v1EdClamp, "v1EdClamp");
async function v1Ed25519PublicKeyFromSeed(seed) {
  const h = await v1Sha512(seed);
  const a = v1EdLeToBig(v1EdClamp(h), 32);
  return v1EdEncode(v1EdMul(a, V1_ED_BASE));
}
__name(v1Ed25519PublicKeyFromSeed, "v1Ed25519PublicKeyFromSeed");
async function v1Ed25519Sign(seed, msg) {
  if (seed.length !== 32) throw new Error("ed25519: semilla de 32 bytes requerida");
  const h = await v1Sha512(seed);
  const a = v1EdLeToBig(v1EdClamp(h), 32);
  const prefix = h.slice(32, 64);
  const A = v1EdEncode(v1EdMul(a, V1_ED_BASE));
  const r = v1EdModL(v1EdLeToBig(await v1Sha512(prefix, msg), 64));
  const R = v1EdEncode(v1EdMul(r, V1_ED_BASE));
  const k = v1EdModL(v1EdLeToBig(await v1Sha512(R, A, msg), 64));
  const S = v1EdModL(r + k * a);
  const sig = new Uint8Array(64);
  sig.set(R, 0);
  sig.set(v1EdBigToLe32(S), 32);
  return sig;
}
__name(v1Ed25519Sign, "v1Ed25519Sign");
async function guardDebugRoute(env, request, path) {
  if (!path.startsWith("/debug")) return null;
  if (String(env.ENABLE_DEBUG_ROUTES || "0") !== "1") {
    return Response.json({ error: "Not found" }, { status: 404 });
  }
  const auth = await verifyAuth(request, env);
  if (!auth.valid) {
    return Response.json({ error: "Unauthorized" }, { status: 401 });
  }
  const destructive = path === "/debug/r2/nuke" || path === "/debug/r2/cleanup" && request.method === "POST" || path === "/debug/patches/duplicates" && request.method === "POST" || path.startsWith("/debug/patch/") && path.endsWith("/extract") && request.method === "POST";
  if (destructive) {
    if (String(env.ENABLE_DESTRUCTIVE_DEBUG || "0") !== "1") {
      return Response.json({ error: "Destructive debug operations disabled" }, { status: 403 });
    }
    if (request.headers.get("X-Confirm-Destructive") !== "yes") {
      return Response.json({ error: "Missing X-Confirm-Destructive: yes" }, { status: 400 });
    }
  }
  return null;
}
__name(guardDebugRoute, "guardDebugRoute");
var RateLimitUnavailable = class extends Error {
  static {
    __name(this, "RateLimitUnavailable");
  }
};
function safeLog(event, error) {
  const types = ["Error", "TypeError", "SyntaxError", "RangeError", "DOMException", "RateLimitUnavailable"];
  const type = types.includes(error?.constructor?.name) ? error.constructor.name : "Error";
  console.error(JSON.stringify({ event, type }));
}
__name(safeLog, "safeLog");
function safeFailure(error, headers = {}) {
  safeLog("request-failed", error);
  const unavailable = error instanceof RateLimitUnavailable;
  return Response.json({ error: unavailable ? "Service temporarily unavailable" : "Internal server error" }, {
    status: unavailable ? 503 : 500,
    headers: { ...headers, "Cache-Control": "no-store", ...unavailable ? { "Retry-After": "30" } : {} }
  });
}
__name(safeFailure, "safeFailure");
var index_default = {
  async fetch(request, env) {
    try {
      return await workerRoutes.fetch(request, env);
    } catch (error) {
      return safeFailure(error);
    }
  }
};
export {
  index_default as default
};
//# sourceMappingURL=index.js.map
