import { google } from 'googleapis';
import db from '../db.js';

// Helper untuk Google Drive upload yang dipakai oleh upload.js & route drive.js

function getOAuthClient() {
  const clientId = process.env.GOOGLE_CLIENT_ID;
  const clientSecret = process.env.GOOGLE_CLIENT_SECRET;
  if (!clientId || !clientSecret) {
    throw new Error('GOOGLE_CLIENT_ID / GOOGLE_CLIENT_SECRET belum diatur di .env');
  }
  const redirectUri = process.env.GOOGLE_REDIRECT_URI
    || `${process.env.BASE_URL || 'http://localhost:3000'}/api/drive/callback`;
  return new google.auth.OAuth2(clientId, clientSecret, redirectUri);
}

export function isDriveConfigured() {
  return Boolean(process.env.GOOGLE_CLIENT_ID && process.env.GOOGLE_CLIENT_SECRET);
}

export function isUserDriveConnected(userId) {
  const user = db.prepare('SELECT google_refresh_token FROM users WHERE id = ?').get(userId);
  return Boolean(user && user.google_refresh_token);
}

async function getDriveForUser(userId) {
  const user = db.prepare('SELECT google_refresh_token, google_drive_email FROM users WHERE id = ?').get(userId);
  if (!user || !user.google_refresh_token) return null;
  const oauth = getOAuthClient();
  oauth.setCredentials({ refresh_token: user.google_refresh_token });
  return { oauth, email: user.google_drive_email };
}

async function findFolder(drive, name) {
  const res = await drive.files.list({
    q: `mimeType='application/vnd.google-apps.folder' and name='${name}' and trashed=false`,
    fields: 'files(id,name)',
    spaces: 'drive',
  });
  return res.data.files?.[0]?.id || null;
}

async function createFolder(drive, name) {
  const res = await drive.files.create({
    requestBody: { name, mimeType: 'application/vnd.google-apps.folder' },
    fields: 'id,name',
  });
  return res.data.id;
}

// Upload buffer ke Google Drive, kembalikan { driveFileId, webViewLink }
export async function uploadBufferToDrive(userId, { filename, mime, buffer }) {
  const gd = await getDriveForUser(userId);
  if (!gd) return null;

  const drive = google.drive({ version: 'v3', auth: gd.oauth });
  const folderName = process.env.DRIVE_FOLDER_NAME || 'Internal Cloud';
  let folderId = await findFolder(drive, folderName);
  if (!folderId) folderId = await createFolder(drive, folderName);

  const fileMetadata = { name: filename, parents: [folderId] };
  const media = { mimeType: mime, body: buffer };
  const resp = await drive.files.create({
    requestBody: fileMetadata,
    media,
    fields: 'id,name,mimeType,size,webViewLink',
  });
  return {
    driveFileId: resp.data.id,
    webViewLink: resp.data.webViewLink || null,
  };
}

export { getOAuthClient };
