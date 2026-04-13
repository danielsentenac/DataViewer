package org.virgo.dataviewer

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.provider.DocumentsContract
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var pendingBackupDirectoryResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "org.virgo.dataviewer/backup",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "pickBackupDirectory" -> pickBackupDirectory(result)
                "writeBackupFile" -> writeBackupFile(call, result)
                else -> result.notImplemented()
            }
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode == REQUEST_CODE_PICK_BACKUP_DIRECTORY) {
            val pendingResult = pendingBackupDirectoryResult
            pendingBackupDirectoryResult = null
            if (pendingResult == null) {
                super.onActivityResult(requestCode, resultCode, data)
                return
            }

            if (resultCode != Activity.RESULT_OK || data?.data == null) {
                pendingResult.success(null)
                return
            }

            val selectedUri = data.data!!
            val grantedFlags =
                data.flags and
                    (Intent.FLAG_GRANT_READ_URI_PERMISSION or
                        Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
            val permissionFlags =
                if (grantedFlags == 0) {
                    Intent.FLAG_GRANT_READ_URI_PERMISSION or
                        Intent.FLAG_GRANT_WRITE_URI_PERMISSION
                } else {
                    grantedFlags
                }

            try {
                contentResolver.takePersistableUriPermission(selectedUri, permissionFlags)
                pendingResult.success(selectedUri.toString())
            } catch (error: SecurityException) {
                pendingResult.error(
                    "backup_permission_denied",
                    "Unable to keep access to the selected backup folder.",
                    error.localizedMessage,
                )
            }
            return
        }

        super.onActivityResult(requestCode, resultCode, data)
    }

    private fun pickBackupDirectory(result: MethodChannel.Result) {
        if (pendingBackupDirectoryResult != null) {
            result.error(
                "backup_request_in_progress",
                "A backup folder request is already running.",
                null,
            )
            return
        }

        pendingBackupDirectoryResult = result
        val intent =
            Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply {
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                addFlags(Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
                addFlags(Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION)
            }
        startActivityForResult(intent, REQUEST_CODE_PICK_BACKUP_DIRECTORY)
    }

    private fun writeBackupFile(call: MethodCall, result: MethodChannel.Result) {
        val directoryUriString = call.argument<String>("directoryUri")
        val fileName = call.argument<String>("fileName")
        val mimeType = call.argument<String>("mimeType")
        val data = call.argument<ByteArray>("data")

        if (directoryUriString.isNullOrBlank()) {
            result.error("invalid_arguments", "Missing backup directory URI.", null)
            return
        }
        if (fileName.isNullOrBlank()) {
            result.error("invalid_arguments", "Missing backup file name.", null)
            return
        }
        if (mimeType.isNullOrBlank()) {
            result.error("invalid_arguments", "Missing backup MIME type.", null)
            return
        }
        if (data == null) {
            result.error("invalid_arguments", "Missing backup file data.", null)
            return
        }

        val directoryUri = Uri.parse(directoryUriString)
        try {
            val treeDocumentId = DocumentsContract.getTreeDocumentId(directoryUri)
            val treeDocumentUri =
                DocumentsContract.buildDocumentUriUsingTree(directoryUri, treeDocumentId)
            val backupFileUri =
                findBackupFileUri(
                    directoryUri = directoryUri,
                    fileName = fileName,
                )
                    ?: DocumentsContract.createDocument(
                        contentResolver,
                        treeDocumentUri,
                        mimeType,
                        fileName,
                    )

            if (backupFileUri == null) {
                result.error(
                    "backup_write_failed",
                    "Unable to create the backup file in the selected folder.",
                    null,
                )
                return
            }

            contentResolver.openOutputStream(backupFileUri, "rwt")?.use { outputStream ->
                outputStream.write(data)
                outputStream.flush()
            } ?: run {
                result.error(
                    "backup_write_failed",
                    "Unable to open the backup file for writing.",
                    null,
                )
                return
            }

            result.success(backupFileUri.toString())
        } catch (error: SecurityException) {
            result.error(
                "backup_permission_denied",
                "The app can no longer write to the configured backup folder.",
                error.localizedMessage,
            )
        } catch (error: IllegalArgumentException) {
            result.error(
                "backup_directory_not_found",
                "The configured backup folder is no longer available.",
                error.localizedMessage,
            )
        } catch (error: Exception) {
            result.error(
                "backup_write_failed",
                "Failed to write the backup file.",
                error.localizedMessage,
            )
        }
    }

    private fun findBackupFileUri(directoryUri: Uri, fileName: String): Uri? {
        val treeDocumentId = DocumentsContract.getTreeDocumentId(directoryUri)
        val childrenUri =
            DocumentsContract.buildChildDocumentsUriUsingTree(directoryUri, treeDocumentId)
        val projection =
            arrayOf(
                DocumentsContract.Document.COLUMN_DOCUMENT_ID,
                DocumentsContract.Document.COLUMN_DISPLAY_NAME,
                DocumentsContract.Document.COLUMN_MIME_TYPE,
            )

        contentResolver.query(childrenUri, projection, null, null, null)?.use { cursor ->
            val documentIdIndex =
                cursor.getColumnIndex(DocumentsContract.Document.COLUMN_DOCUMENT_ID)
            val displayNameIndex =
                cursor.getColumnIndex(DocumentsContract.Document.COLUMN_DISPLAY_NAME)
            val mimeTypeIndex =
                cursor.getColumnIndex(DocumentsContract.Document.COLUMN_MIME_TYPE)

            while (cursor.moveToNext()) {
                val displayName = cursor.getString(displayNameIndex)
                if (displayName != fileName) {
                    continue
                }

                val mimeType = cursor.getString(mimeTypeIndex)
                if (mimeType == DocumentsContract.Document.MIME_TYPE_DIR) {
                    continue
                }

                val documentId = cursor.getString(documentIdIndex)
                return DocumentsContract.buildDocumentUriUsingTree(directoryUri, documentId)
            }
        }

        return null
    }

    private companion object {
        const val REQUEST_CODE_PICK_BACKUP_DIRECTORY = 19121
    }
}
