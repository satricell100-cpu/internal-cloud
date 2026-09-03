import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import { S3Client, PutObjectCommand, DeleteObjectCommand, GetObjectCommand, HeadObjectCommand } from '@aws-sdk/client-s3';
import { Readable } from 'stream';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const DATA_DIR = path.resolve(__dirname, '../../data');
const LOCAL_UPLOAD_DIR = path.join(DATA_DIR, 'uploads');

fs.mkdirSync(LOCAL_UPLOAD_DIR, { recursive: true });

function getDriver() {
  return (process.env.STORAGE_DRIVER || 'local').trim().toLowerCase();
}

function getBucketConfig() {
  return {
    bucket: process.env.S3_BUCKET || '',
    region: process.env.S3_REGION || 'us-east-1',
    endpoint: process.env.S3_ENDPOINT || '',
    forcePathStyle: (process.env.S3_FORCE_PATH_STYLE || 'true').toLowerCase() !== 'false',
    accessKeyId: process.env.S3_ACCESS_KEY_ID || '',
    secretAccessKey: process.env.S3_SECRET_ACCESS_KEY || '',
    prefix: (process.env.S3_PREFIX || 'internal-cloud').replace(/^\/+|\/+$/g, ''),
  };
}

function makeS3Client() {
  const cfg = getBucketConfig();
  if (!cfg.bucket) throw new Error('S3_BUCKET belum diisi');
  if (!cfg.accessKeyId || !cfg.secretAccessKey) throw new Error('S3_ACCESS_KEY_ID / S3_SECRET_ACCESS_KEY belum diisi');
  const clientCfg = {
    region: cfg.region,
    credentials: {
      accessKeyId: cfg.accessKeyId,
      secretAccessKey: cfg.secretAccessKey,
    },
    forcePathStyle: cfg.forcePathStyle,
  };
  if (cfg.endpoint) clientCfg.endpoint = cfg.endpoint;
  return new S3Client(clientCfg);
}

function s3Key(storedName) {
  const { prefix } = getBucketConfig();
  return prefix ? `${prefix}/${storedName}` : storedName;
}

async function streamToBuffer(stream) {
  const chunks = [];
  for await (const chunk of stream) chunks.push(Buffer.from(chunk));
  return Buffer.concat(chunks);
}

export function getStorageMode() {
  return getDriver();
}

export function getLocalUploadDir() {
  return LOCAL_UPLOAD_DIR;
}

export function buildStoredName(fileId, ext) {
  return `${fileId}.${ext}`;
}

export function buildLocalPath(storedName) {
  return path.join(LOCAL_UPLOAD_DIR, storedName);
}

export async function saveObject({ storedName, buffer }) {
  const mode = getDriver();
  if (mode === 'local') {
    const filePath = buildLocalPath(storedName);
    await fs.promises.writeFile(filePath, buffer);
    return { storedName, path: filePath, mode: 'local' };
  }
  if (mode === 's3') {
    const cfg = getBucketConfig();
    const client = makeS3Client();
    const key = s3Key(storedName);
    await client.send(new PutObjectCommand({
      Bucket: cfg.bucket,
      Key: key,
      Body: buffer,
    }));
    return { storedName, key, mode: 's3' };
  }
  throw new Error(`Storage driver '${mode}' belum didukung. Gunakan local atau s3.`);
}

export async function deleteObject(storedName) {
  const mode = getDriver();
  if (mode === 'local') {
    const filePath = buildLocalPath(storedName);
    if (fs.existsSync(filePath)) await fs.promises.unlink(filePath);
    return;
  }
  if (mode === 's3') {
    const cfg = getBucketConfig();
    const client = makeS3Client();
    await client.send(new DeleteObjectCommand({ Bucket: cfg.bucket, Key: s3Key(storedName) }));
    return;
  }
  throw new Error(`Storage driver '${mode}' belum didukung. Gunakan local atau s3.`);
}

export async function resolveObjectPath(storedName) {
  const mode = getDriver();
  if (mode === 'local') {
    return buildLocalPath(storedName);
  }
  if (mode === 's3') {
    const cfg = getBucketConfig();
    const client = makeS3Client();
    const resp = await client.send(new GetObjectCommand({ Bucket: cfg.bucket, Key: s3Key(storedName) }));
    const buf = await streamToBuffer(resp.Body);
    const tmpPath = path.join(DATA_DIR, 'tmp', storedName);
    await fs.promises.mkdir(path.dirname(tmpPath), { recursive: true });
    await fs.promises.writeFile(tmpPath, buf);
    return tmpPath;
  }
  throw new Error(`Storage driver '${mode}' belum didukung. Gunakan local atau s3.`);
}

export async function objectExists(storedName) {
  const mode = getDriver();
  if (mode === 'local') {
    return fs.existsSync(buildLocalPath(storedName));
  }
  if (mode === 's3') {
    const cfg = getBucketConfig();
    const client = makeS3Client();
    try {
      await client.send(new HeadObjectCommand({ Bucket: cfg.bucket, Key: s3Key(storedName) }));
      return true;
    } catch {
      return false;
    }
  }
  throw new Error(`Storage driver '${mode}' belum didukung. Gunakan local atau s3.`);
}
