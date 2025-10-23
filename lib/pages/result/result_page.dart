library result_page;

import 'dart:convert';
import 'dart:io';

import "package:collection/collection.dart";
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:multi_select_flutter/multi_select_flutter.dart';
import 'package:navy_encrypt/common/encrypt_decrypt_header.dart';
import 'package:navy_encrypt/common/file_details.dart';
import 'package:navy_encrypt/common/header_scaffold.dart';
import 'package:navy_encrypt/common/my_button.dart';
import 'package:navy_encrypt/common/my_container.dart';
import 'package:navy_encrypt/common/my_dialog.dart';
import 'package:navy_encrypt/common/my_state.dart';
import 'package:navy_encrypt/common/widget_view.dart';
import 'package:navy_encrypt/etc/constants.dart';
import 'package:navy_encrypt/etc/file_util.dart';
import 'package:navy_encrypt/etc/utils.dart';
import 'package:navy_encrypt/models/my_file_type.dart';
import 'package:navy_encrypt/models/share_log.dart';
import 'package:navy_encrypt/models/user.dart';
import 'package:navy_encrypt/navy_encryption/navec.dart';
import 'package:navy_encrypt/pages/cloud_picker/cloud_picker_page.dart';
import 'package:navy_encrypt/pages/cloud_picker/google_drive.dart';
import 'package:navy_encrypt/pages/cloud_picker/icloud_drive.dart';
import 'package:navy_encrypt/pages/cloud_picker/local_drive.dart';
import 'package:navy_encrypt/pages/cloud_picker/onedrive.dart';
import 'package:navy_encrypt/pages/encryption/encryption_page.dart';
import 'package:navy_encrypt/services/api.dart';
import 'package:navy_encrypt/storage/prefs.dart';
import 'package:open_file/open_file.dart';
import 'package:path/path.dart' as p;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:permission_handler/permission_handler.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

part 'result_page_view.dart';
part 'result_page_view_win.dart';

class ResultPage extends StatefulWidget {
  static const routeName = 'result';

  const ResultPage({Key key}) : super(key: key);

  @override
  _ResultPageController createState() => _ResultPageController();
}

class _ResultPageController extends MyState<ResultPage> {
  static const int _maxFileSizeInBytes = 20 * 1024 * 1024;
  String _filePath;
  String _message;
  bool _isEncFile;
  String _fileEncryptPath;
  List<User> _shareSelected;

  List<ShareLog> _shareLog;
  Map<int, List<ShareLog>> _shareLogGroup;
  String _signatureCode;
  String _type;
  String _userID;
  bool _saveStstus = false;
  final _multiSelectKey = GlobalKey<FormFieldState>();

  @override
  void initState() {
    _shareSelected = [];
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    // print(
    //     "_multiSelectKey.currentState.validate()${_multiSelectKey.currentState.value()}");
    var arguments =
        ModalRoute.of(context).settings.arguments as Map<String, dynamic>;
    _filePath = arguments['filePath'] as String;
    _message = arguments['message'] as String;
    _userID = arguments['userID'] as String;
    // _fileEncryptPath =
    //     arguments['fileEncryptPath'] ?? arguments['filePath'] as String;

    _fileEncryptPath = arguments['filePath'] as String;

    assert(_filePath != null && _filePath.isNotEmpty);

    _isEncFile = arguments['isEncryption'] as bool;
    _signatureCode = arguments['signatureCode'] as String;
    _type = arguments['type'] as String;

    logOneLineWithBorderSingle('File path: $_filePath');
    logOneLineWithBorderSingle('File path: $_userID');
    return isLandscapeLayout(context)
        ? _ResultPageViewWin(this)
        : _ResultPageView(this);
  }

  bool _isImageFile() {
    var extension = p.extension(_filePath);
    if (extension?.isEmpty ?? true) return false;
    return Constants.imageFileTypeList
        .where((type) =>
            type.fileExtension.toLowerCase() ==
            extension.substring(1).toLowerCase())
        .isNotEmpty;
  }

  _goEncryption() {
    Navigator.pushReplacementNamed(
      context,
      EncryptionPage.routeName,
      arguments: _filePath,
    );
  }

  _getShareLog(logId) async {
    isLoading = true;

    // print("onShare = ${logId}");
    isLoading = true;
    List<ShareLog> shareLog = await MyApi().getShareLog(int.parse(logId));
    final shareLogGroup = shareLog.groupListsBy((m) => m.id);

    isLoading = false;
    setState(() {
      // _shareLog = shareLog;
      _shareLogGroup = shareLogGroup;
    });
  }

  _handleClickSaveButton() async {
    if (await _resolveResultFile() == null) {
      return;
    }

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return MyDialog.buildPickerDialog(
          headerImage: Icon(FontAwesomeIcons.fileUpload,
              size: Constants.LIST_DIALOG_HEADER_IMAGE_SIZE,
              color: Color(0xFF3EC2FF)),
          items: [
            if (_isImageFile())
              DialogTileData(
                label: 'รูปภาพ',
                image: Image.asset(
                  'assets/images/ic_gallery.png',
                  width: Constants.LIST_DIALOG_ICON_SIZE,
                  height: Constants.LIST_DIALOG_ICON_SIZE,
                ),
                onClick: () {
                  setState(() {
                    _saveStstus = true;
                  });
                  Navigator.of(context).pop();
                  _saveToGallery();
                },
              ),
            DialogTileData(
              label:
                  'โฟลเดอร์ของแอป${Platform.isWindows ? ' ' : '\n'}(App\'s Documents Folder)',
              image: Icon(
                FontAwesomeIcons.solidFolderOpen,
                size: Constants.LIST_DIALOG_ICON_SIZE,
                color: Constants.LIST_DIALOG_ICON_COLOR,
              ),
              onClick: () {
                setState(() {
                  _saveStstus = true;
                });
                Navigator.of(context).pop();
                _saveToDocFolder();
              },
            ),
            if (!Platform.isIOS)
              DialogTileData(
                label:
                    'โฟลเดอร์อื่นๆ${Platform.isWindows ? ' ' : '\n'}(เลือกจาก System Dialog)',
                image: Icon(
                  FontAwesomeIcons.sdCard,
                  size: Constants.LIST_DIALOG_ICON_SIZE,
                  color: Constants.LIST_DIALOG_ICON_COLOR,
                ),
                onClick: () {
                  setState(() {
                    _saveStstus = true;
                  });
                  Navigator.of(context).pop();
                  _saveToLocalStorage();

                  // ทำไม delay ไม่ work!!!
                  /*Future.delayed(Duration(microseconds: 1000), () async {
                  await _saveToLocalStorage();
                });*/
                },
              ),
            if (Platform.isIOS)
              DialogTileData(
                label: 'iCloud',
                image: Icon(
                  FontAwesomeIcons.cloud,
                  size: Constants.LIST_DIALOG_ICON_SIZE,
                  color: Constants.LIST_DIALOG_ICON_COLOR,
                ),
                onClick: () {
                  setState(() {
                    _saveStstus = true;
                  });
                  Navigator.of(context).pop();
                  _saveToICloud();
                },
              ),
            DialogTileData(
              label: 'Google Drive',
              image: Image.asset(
                'assets/images/ic_google_drive.png',
                width: Constants.LIST_DIALOG_ICON_SIZE,
                height: Constants.LIST_DIALOG_ICON_SIZE,
              ),
              onClick: () {
                setState(() {
                  _saveStstus = true;
                });
                _saveToGoogleDrive();
                Navigator.of(context).pop();
              },
            ),
            DialogTileData(
              label: 'OneDrive',
              image: Image.asset(
                'assets/images/ic_onedrive_new.png',
                width: Constants.LIST_DIALOG_ICON_SIZE,
                height: Constants.LIST_DIALOG_ICON_SIZE,
              ),
              onClick: () {
                setState(() {
                  _saveStstus = true;
                });
                _saveToOneDrive();
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  _saveToGallery() async {
    final file = await _resolveResultFile();
    if (file == null) {
      return;
    }

    // Windows
    if (Platform.isWindows) {
      var localDrive = LocalDrive(
        CloudPickerMode.folder,
        (await FileUtil.getImageDirPath()),
      );
      Navigator.pushNamed(
        context,
        CloudPickerPage.routeName,
        arguments: CloudPickerPageArg(
          cloudDrive: localDrive..fileToUpload = file,
          title: 'รูปภาพ',
          headerImagePath: 'assets/images/ic_gallery.png',
          rootName: 'Pictures',
        ),
        //arguments: localDrive..fileToUpload = File(_filePath),
      );
      return;
    }
    // Android, iOS
    else {
      var status = await Permission.storage.status;
      if (status.isGranted) {
        await _doSaveToGallery(file);
      } else {
        status = await Permission.storage.request();
        if (status.isGranted) {
          await _doSaveToGallery(file);
        } else {
          _showSnackBar('แอปไม่ได้รับอนุญาตให้บันทึกไฟล์');
        }
      }
    }
  }

  _doSaveToGallery(File file) async {
    try {
      var result = await ImageGallerySaverPlus.saveImage(
      await file.readAsBytes(),
      quality: 100,
    );
      showOkDialog(
        context,
        result['isSuccess']
            ? 'บันทึกลงในคลังภาพสำเร็จ'
            : 'เกิดข้อผิดพลาดในการบันทึกลงในคลังภาพ',
      );
    } catch (error) {
      _showSnackBar('เกิดข้อผิดพลาด: ${error.toString()}');
    }
  }

  // _saveToDocFolder() async {
  //   var localDrive = LocalDrive(
  //     CloudPickerMode.folder,
  //     (await FileUtil.getDocDir()).path,
  //   );
  //
  //   Directory appDocDirectory = Platform.isAndroid
  //       ? await getExternalStorageDirectory() //FOR ANDROID
  //       : await getApplicationSupportDirectory(); //FOR iOS
  //   var encoder = ZipFileEncoder();
  //
  //   encoder.create(appDocDirectory.path + "/" + 'jay2.zip');
  //
  //   encoder.addFile(File(_filePath));
  //
  //   encoder.close();
  //   final bytes = File(_filePath).readAsBytesSync();
  //
  //   Navigator.pushNamed(
  //     context,
  //     CloudPickerPage.routeName,
  //     arguments: CloudPickerPageArg(
  //         cloudDrive: localDrive..fileToUpload = File(encoder.zipPath),
  //         title: 'โฟลเดอร์ของแอป',
  //         headerImagePath: 'assets/images/ic_document.png',
  //         rootName: 'App\'s Folder'),
  //     //arguments: localDrive..fileToUpload = File(_filePath),
  //   );
  // }

  _saveToDocFolder() async {
    final file = await _resolveResultFile();
    if (file == null) {
      return;
    }

    var localDrive = LocalDrive(
      CloudPickerMode.folder,
      (await FileUtil.getDocDir()).path,
    );
    Navigator.pushNamed(
      context,
      CloudPickerPage.routeName,
      arguments: CloudPickerPageArg(
          cloudDrive: localDrive..fileToUpload = file,
          title: 'โฟลเดอรs์ของแอป',
          headerImagePath: 'assets/images/ic_document.png',
          rootName: 'App\'s Folder'),
      //arguments: localDrive..fileToUpload = File(_filePath),
    );
  }

  _saveToICloud() async {
    final file = await _resolveResultFile();
    if (file == null) {
      return;
    }

    var localDrive = ICloudDrive(
      CloudPickerMode.folder,
      '',
    );
    Navigator.pushNamed(
      context,
      CloudPickerPage.routeName,
      arguments: CloudPickerPageArg(
          cloudDrive: localDrive..fileToUpload = file,
          title: 'iCloud',
          headerImagePath: 'assets/images/ic_icloud.png',
          rootName: 'iCloud'),
      //arguments: localDrive..fileToUpload = File(_filePath),
    );
  }

  Future<void> _saveToLocalStorage() async {
    final file = await _resolveResultFile();
    if (file == null) {
      return;
    }

    //isLoading = true;
    //loadingMessage = 'กำลังแสดงไดอะล็อกสำหรับเลือกโฟลเดอร์ที่จะบันทึกไฟล์';

    Future.delayed(Duration(microseconds: 500), () async {
      if (Platform.isWindows) {
        //await _saveFile(selectedDirectory);

        // Save-file / save-as dialog - ใช้ได้เฉพาะ desktop
        String outputFilePath = await FilePicker.platform.saveFile(
          dialogTitle: 'เลือกโฟลเดอร์และชื่อไฟล์ที่จะบันทึก',
          fileName: p.basename(file.path),
          //type: FileType.image,
        );
        if (outputFilePath == null) {
          // User canceled the picker
          _showSnackBar('ยกเลิกการเลือกไฟล์');
        } else {
          await _saveFile(outputFilePath,
              sourceFile: file, isFullPath: true);
        }
      } else {
        // Pick a directory
        String selectedDirectory = await FilePicker.platform.getDirectoryPath();
        if (selectedDirectory == null) {
          // User canceled the picker
          //isLoading = false;
          _showSnackBar('ยกเลิกการเลือกไฟล์');
        } else {
          logOneLineWithBorderDouble('SELECTED DIR: $selectedDirectory');

          var status = await Permission.storage.status;
          if (status.isGranted) {
            await _saveFile(selectedDirectory, sourceFile: file);
          } else {
            status = await Permission.storage.request();
            if (status.isGranted) {
              await _saveFile(selectedDirectory, sourceFile: file);
            } else {
              _showSnackBar('แอปไม่ได้รับอนุญาตให้บันทึกไฟล์');
            }
          }
          //isLoading = false;
        }
      }
    });
  }

  Future<void> _saveFile(String selectedPath,
      {File sourceFile, bool isFullPath = false}) async {
    final file = sourceFile ?? await _resolveResultFile();
    if (file == null) {
      return;
    }

    final targetPath =
        isFullPath ? selectedPath : p.join(selectedPath, p.basename(file.path));
    logOneLineWithBorderSingle('COPYING TO $targetPath');
    try {
      isLoading = true;
      loadingMessage = 'กำลังบันทึกไฟล์';

      await file.copy(targetPath);
      showOkDialog(
        context,
        'สำเร็จ',
        textContent: 'บันทึกไฟล์สำเร็จ',
      );
    } catch (e) {
      _showSnackBar('เกิดข้อผิดพลาด: ${e.toString()}');
    } finally {
      isLoading = false;
    }
  }

  _saveToGoogleDrive() async {
    final file = await _resolveResultFile();
    if (file == null) {
      return;
    }

    isLoading = true;
    loadingMessage = 'กำลังลงทะเบียนเข้าใช้งาน Google Drive';
    var googleDrive = GoogleDrive(CloudPickerMode.folder);
    bool signInSuccess = false;
    try {
      signInSuccess = Platform.isWindows
          ? await googleDrive.signInWithOAuth2()
          : await googleDrive.signIn();
    } catch (error) {
      _showSnackBar('เกิดข้อผิดพลาด: ${error.toString()}');
      if (mounted) {
        isLoading = false;
      }
      return;
    }

    if (signInSuccess) {
      Navigator.pushNamed(
        context,
        CloudPickerPage.routeName,
        arguments: CloudPickerPageArg(
          cloudDrive: googleDrive..fileToUpload = file,
          title: 'Google Drive',
          headerImagePath: 'assets/images/ic_google_drive.png',
          rootName: 'Drive',
        ),
        //arguments: googleDrive..fileToUpload = File(_filePath),
      );
    } else {
      _showSnackBar('ยกเลิกการเลือกไฟล์');
    }
    if (mounted) {
      isLoading = false;
    }
  }

  _saveToOneDrive() async {
    final file = await _resolveResultFile();
    if (file == null) {
      return;
    }

    isLoading = true;
    loadingMessage = 'กำลังลงทะเบียนเข้าใช้งาน OneDrive';
    var oneDrive = OneDrive(CloudPickerMode.folder);
    bool signInSuccess = false;
    try {
      signInSuccess = Platform.isWindows
          ? await oneDrive.signInWithOAuth2()
          : await oneDrive.signIn();
    } catch (error) {
      _showSnackBar('เกิดข้อผิดพลาด: ${error.toString()}');
      if (mounted) {
        isLoading = false;
      }
      return;
    }

    if (signInSuccess) {
      Navigator.pushNamed(
        context,
        CloudPickerPage.routeName,
        arguments: CloudPickerPageArg(
          cloudDrive: oneDrive..fileToUpload = file,
          title: 'OneDrive',
          headerImagePath: 'assets/images/ic_onedrive_new.png',
          rootName: 'Drive',
        ),
      );
    } else {
      _showSnackBar('ยกเลิกการเลือกไฟล์');
    }
    if (mounted) {
      isLoading = false;
    }
  }

  _handleClickShareButton() async {
    final file = await _resolveResultFile();
    if (file == null) {
      return;
    }

    try {
      if (Platform.isWindows) {
        await Process.run('explorer', ['/select,', file.path]);
        return;
      }

      final xFile = XFile(file.path);
      if (await isIpad()) {
        await Share.shareXFiles(
          [xFile],
          sharePositionOrigin: Rect.fromLTWH(
            0,
            0,
            screenWidth(context),
            screenHeight(context) / 2,
          ),
        );
      } else {
        await Share.shareXFiles([xFile]);
      }
    } catch (error) {
      _showSnackBar('เกิดข้อผิดพลาด: ${error.toString()}');
    }
  }

  Future<void> _handleClickOpenButton() async {
    final file = await _resolveResultFile();
    if (file == null) {
      return;
    }

    try {
      final result = await OpenFile.open(file.path);
      if (result.type == ResultType.noAppToOpen) {
        _showSnackBar('ไม่พบแอปที่ใช้เปิดไฟล์ประเภทนี้');
      }
    } catch (error) {
      _showSnackBar('เกิดข้อผิดพลาด: ${error.toString()}');
    }
  }

  _pickEmailShare() async {
    // ยืนยันบันทึกข้อมูลก่อนอนุญาต
    await _getShareLog(_userID);

    if (!_saveStstus) {
      bool isSave = false;
      //   await showAlertDialog(
      //     context,
      //     'แจ้งเตือน',
      //     textContent: 'คุณต้องการบันทึกก่อนหรือไม่ ?',
      //     content: null,
      //     dismissible: false,
      //     buttonList: [
      //       DialogActionButton(label: 'ไม่ใช่', onClick: null),
      //       DialogActionButton(
      //           label: 'ใช่',
      //           onClick: () async {
      //             isSave = true;
      //           }),
      //     ],
      //   );
      //   if (isSave) {
      //     return;
      //   }
    }

    // END ยืนยันบันทึกข้อมูลก่อนอนุญาต

    isLoading = true;
    final _contacts = await MyApi().getUser();
    final email = await MyPrefs.getEmail();
    _contacts.removeWhere((item) => item.email == email);
    isLoading = false;

    setState(() {
      _shareSelected = [];
    });
    // _shareLog

    final _items = _contacts
        .map((contacts) => MultiSelectItem<User>(
              contacts,
              (contacts.name + '\n' + contacts.email),
            ))
        .toList();

    if (_type == 'watermark') {
      _handleClickShareButton();
      return;
    }

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (context, setState) {
          return MyDialog(
            headerImage: Image.asset('assets/images/ic_contact.png',
                width: Constants.LIST_DIALOG_HEADER_IMAGE_SIZE),
            body: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(height: 32.0),
                  Text(
                    'เลือกอีเมลที่อนุญาตให้ถอดรหัส',
                    textAlign: TextAlign.center,
                    style:
                        TextStyle(fontSize: 22.0, fontWeight: FontWeight.w500),
                  ),
                  SizedBox(height: 12.0),
                  // เลือกรายการอีเมล
                  MultiSelectDialogField<User>(
                    key: _multiSelectKey,
                    items: _items,
                    title: Text(
                      "รายการทั้งหมด",
                    ),
                    searchable: true,
                    dialogHeight: MediaQuery.of(context).size.height * 0.6,
                    dialogWidth: MediaQuery.of(context).size.width * 0.8,
                    selectedColor: Color(0xFF3EC2FF),
                    decoration: BoxDecoration(
                      color: Color(0xFF3EC2FF).withOpacity(0.1),
                      borderRadius: BorderRadius.all(Radius.circular(2)),
                      border: Border.all(
                        color: Color(0xFF3EC2FF),
                        width: 1,
                      ),
                    ),
                    buttonIcon: Icon(
                      Icons.contacts,
                      color: Color(0xFF3EC2FF),
                    ),
                    buttonText: Text(
                      "อีเมล",
                      style: TextStyle(
                        fontSize: 20,
                      ),
                    ),
                    confirmText: Text("ตกลง",
                        style: TextStyle(
                            color: Color.fromARGB(255, 31, 150, 205))),
                    cancelText: Text("ปิด",
                        style: TextStyle(
                            color: Color.fromARGB(255, 136, 136, 136))),
                    chipDisplay: MultiSelectChipDisplay.none(
                      disabled: false,
                    ),
                    itemsTextStyle: TextStyle(
                      fontSize: 20,
                      fontFamily: 'DBHeavent',
                    ),
                    selectedItemsTextStyle: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 20,
                      fontFamily: 'DBHeavent',
                    ),
                    searchTextStyle: TextStyle(
                      fontWeight: FontWeight.normal,
                      fontSize: 20,
                      fontFamily: 'DBHeavent',
                    ),
                    onConfirm: (results) async {
                      print("getEMail =${results[0].email}");
                      // print("getEMail =${results[1].email}");
                      setState(() {
                        _shareSelected = results;
                      });
                      // print("_shareSelected =${_shareSelected}");

                      _multiSelectKey.currentState.validate();

                      // List<int> shareUserId = [];
                      // _shareSelected
                      //     .forEach((User user) => shareUserId.add(user.id));
                      // prefs.setString("shareId", shareUserId.toString());
                      // print(
                      //     "aaaaaksod ${json.encode(prefs.getString('shareId'))}");
                      // print(
                      //     "aaaaaksod ${json.decode(prefs.getString('shareId'))}");
                    },
                  ),
                  SizedBox(height: 12.0),
                  // buildMailShareSelect(),
                  if (_shareSelected.length > 0)
                    Container(
                        child: Column(children: [
                      SizedBox(height: 6.0),
                      Text(
                        'รายการอีเมลที่เลือก',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 22.0, fontWeight: FontWeight.w500),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.all(Radius.circular(2)),
                          border: Border.all(
                            color: Color(0xFF3EC2FF),
                            width: 1,
                          ),
                        ),
                        constraints: BoxConstraints(
                            minWidth: double.infinity, maxHeight: 250),
                        child: Scrollbar(
                            child: ListView.builder(
                          padding: EdgeInsets.all(0.0),
                          shrinkWrap: true,
                          itemCount: _shareSelected.length,
                          itemBuilder: (BuildContext context, int index) {
                            print(
                                "_shareSelected[index].name ${_shareSelected[index].name}");
                            print(
                                "_shareSelected[index].name ${_shareSelected[index].email}");
                            return ListTile(
                              contentPadding: EdgeInsets.only(
                                  left: 8, top: 0, bottom: 0, right: 0),
                              title: Text(_shareSelected[index].name,
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontFamily: 'DBHeavent',
                                  )),
                              subtitle: Text(
                                _shareSelected[index].email,
                                style: TextStyle(
                                  fontSize: 22,
                                  fontFamily: 'DBHeavent',
                                ),
                              ),
                              trailing: IconButton(
                                padding: const EdgeInsets.all(0.0),
                                icon: Icon(Icons.remove_circle,
                                    color: Color(0xFF3EC2FF)),
                                onPressed: () {
                                  setState(() {
                                    _shareSelected
                                        .remove(_shareSelected[index]);
                                  });
                                  _multiSelectKey.currentState.validate();
                                },
                              ),
                              dense: true,
                            );
                          },
                        )),
                      ),
                      SizedBox(height: 6.0),
                      Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            _shareSelected.length.toString() + ' รายการ',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 22.0),
                          )),
                    ])),

                  OverflowBar(
                    alignment: MainAxisAlignment.end,
                    // spacing: spacing,
                    overflowAlignment: OverflowBarAlignment.end,
                    overflowDirection: VerticalDirection.down,
                    overflowSpacing: 0,
                    children: <Widget>[
                      TextButton(
                        child: Text("ปิด",
                            style: TextStyle(
                                color: Color.fromARGB(255, 136, 136, 136))),
                        onPressed: () {
                          Navigator.pop(context, false);
                        },
                      ),
                      TextButton(
                        child: Text("ตกลง",
                            style: TextStyle(
                                color: Color.fromARGB(255, 31, 150, 205))),
                        onPressed: () async {
                          if (_shareSelected.length > 0) {
                            // print(
                            //     "_shareSelected[0].name${_shareSelected[0].name}");
                            // print(
                            //     "_shareSelected[0].name${_shareSelected[0].id}");
                            final status = await _saveLog();

                            if (status && !Platform.isWindows) {
                              _handleClickShareButton();
                            }

                            Navigator.pop(context, false);
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            padding: EdgeInsets.only(
              left: 16.0,
              top: 16.0,
              right: 16.0,
              bottom: 0.0,
            ),
          );
        });
      },
    );
  }

  Widget getShareReceive(List<ShareLog> data, BuildContext context) {
    return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: List.generate(
            data.length,
            (index) => Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SizedBox(
                      width: 24,
                    ),
                    Icon(
                      FontAwesomeIcons.userAlt,
                      size: 15,
                    ),
                    Text('  ${data[index].receiveName}',
                        style: TextStyle(
                          fontSize: 22,
                        ))
                  ],
                )));
  }

  Future<bool> _saveLog() async {
    //SAVE LOG
    bool status = false;
    try {
      String uuid;
      try {
        var fileBytes = await File(_fileEncryptPath).readAsBytes();
        uuid = utf8
            .decode(fileBytes.sublist(
              (fileBytes.length - Navec.headerUUIDFieldLength),
            ))
            .trim();
      } catch (err) {}

      if (((_type == 'encryption' && uuid != null) || (_type == 'watermark')) &&
          _fileEncryptPath != null) {
        var email = await MyPrefs.getEmail();
        var secret = await MyPrefs.getSecret();
        String fileName = '${p.basename(_fileEncryptPath)}';
        List<int> shareUserId = [];
        _shareSelected.forEach((User user) => shareUserId.add(user.id));

        final logId = await MyApi().saveLog(email, fileName, uuid,
            _signatureCode, 'share', _type, secret, shareUserId);
        print("logDATA ${logId}");
        if (logId == null) {
          showOkDialog(
            context,
            'ผิดพลาด',
            textContent: 'ไม่สามารถดำเนินการ\nหรือบัญชีของท่านรอการตรวจสอบ!',
          );

          isLoading = false;
          // return;
        }
        status = true;
      } else {
        status = true;
      }
    } catch (e) {
      showOkDialog(context, e.toString());
      isLoading = false;
      // return;
    }
    return status;
    // END SAVE LOG
  }

  _handlePrintingButton() async {
    final file = await _resolveResultFile();
    if (file == null) {
      return;
    }

    final doc = pw.Document();
    final extension = p.extension(file.path).substring(1).toLowerCase();

    try {
      if (_isType(Constants.imageFileTypeList, extension)) {
        final image = pw.MemoryImage(await file.readAsBytes());

        doc.addPage(pw.Page(
            pageFormat: PdfPageFormat.a4,
            build: (pw.Context context) {
              return pw.Center(child: pw.Image(image));
            }));

        await Printing.layoutPdf(
            onLayout: (PdfPageFormat format) async => await doc.save());
      } else if (_isType(Constants.documentFileTypeList, extension)) {
        final pdfBytes = await file.readAsBytes();
        await Printing.layoutPdf(
            onLayout: (_) => pdfBytes.buffer.asUint8List());
      } else if (extension.toLowerCase() == 'zip') {
        final uniqueTempDirPath =
            (await FileUtil.createUniqueTempDir()).path;
        await file.copy('$uniqueTempDirPath/images.zip');
        FileUtil.unzip(dirPath: uniqueTempDirPath, filename: 'images.zip');

        final filePathList =
            Directory(uniqueTempDirPath /*p.join(p.dirname(filePath), 'images')*/)
                .listSync()
                .map((file) => file.path)
                .toList();

        for (final ele in filePathList) {
          if (_isType(Constants.imageFileTypeList,
              p.extension(ele).substring(1).toLowerCase())) {
            final image = pw.MemoryImage(File(ele).readAsBytesSync());

            doc.addPage(pw.Page(
                pageFormat: PdfPageFormat.a4,
                build: (pw.Context context) {
                  return pw.Center(child: pw.Image(image));
                }));
          }
        }

        await Printing.layoutPdf(
            onLayout: (PdfPageFormat format) async => await doc.save());
      } else {
        showOkDialog(
          context,
          'ผิดพลาด',
          textContent: 'รูปแบบไฟล์ไม่รองรับ!',
        );
      }
    } catch (error) {
      _showSnackBar('เกิดข้อผิดพลาด: ${error.toString()}');
    }
  }

  bool _isType(List<MyFileType> fileTypeList, String fileExtension) {
    return fileTypeList
            .where((fileType) => fileType.fileExtension == fileExtension)
            .length >
        0;
  }

  Future<File> _resolveResultFile() async {
    if (_filePath == null || _filePath.isEmpty) {
      _showSnackBar('ไม่พบไฟล์');
      return null;
    }

    try {
      final file = File(_filePath);
      if (!await file.exists()) {
        _showSnackBar('ไม่พบไฟล์');
        return null;
      }

      final size = await file.length();
      if (size <= 0) {
        _showSnackBar('ไม่พบไฟล์');
        return null;
      }

      if (size > _maxFileSizeInBytes) {
        _showSnackBar('ไฟล์มีขนาดเกิน 20MB');
        return null;
      }

      return file;
    } catch (error) {
      _showSnackBar('เกิดข้อผิดพลาด: ${error.toString()}');
      return null;
    }
  }

  void _showSnackBar(String message) {
    if (!mounted || message == null || message.isEmpty) {
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _ResultActionData {
  final String label;
  final Widget icon;
  final VoidCallback onPressed;

  const _ResultActionData({this.label, this.icon, this.onPressed});
}

List<_ResultActionData> buildResultActions(_ResultPageController state) {
  final actions = <_ResultActionData>[
    _ResultActionData(
      label: 'บันทึก',
      icon: Icon(Icons.save, size: 18.0),
      onPressed: state._handleClickSaveButton,
    ),
  ];

  if (state._isEncFile == true && !Platform.isWindows) {
    actions.add(
      _ResultActionData(
        label: 'เปิด',
        icon: Icon(Icons.article_outlined, size: 18.0),
        onPressed: state._handleClickOpenButton,
      ),
    );
  } else {
    actions.add(
      _ResultActionData(
        label: 'อนุญาต',
        icon: Icon(Icons.contacts, size: 18.0),
        onPressed: state._pickEmailShare,
      ),
    );
  }

  if (state._isEncFile == true && Platform.isWindows) {
    actions.add(
      _ResultActionData(
        label: 'เปิด',
        icon: Icon(Icons.article_outlined, size: 18.0),
        onPressed: state._handleClickOpenButton,
      ),
    );
  } else {
    actions.add(
      _ResultActionData(
        label: 'แชร์',
        icon: Icon(Icons.share, size: 18.0),
        onPressed: state._handleClickShareButton,
      ),
    );
  }

  if (state._isEncFile == true) {
    actions.add(
      _ResultActionData(
        label: 'เข้ารหัส',
        icon: Icon(Icons.enhanced_encryption_outlined, size: 18.0),
        onPressed: state._goEncryption,
      ),
    );
  }

  actions.add(
    _ResultActionData(
      label: 'พิมพ์',
      icon: Icon(Icons.print, size: 18.0),
      onPressed: state._handlePrintingButton,
    ),
  );

  return actions;
}

class _ResultActionData {
  final String label;
  final Widget icon;
  final VoidCallback onPressed;

  const _ResultActionData({this.label, this.icon, this.onPressed});
}

List<_ResultActionData> buildResultActions(_ResultPageController state) {
  final actions = <_ResultActionData>[
    _ResultActionData(
      label: 'บันทึก',
      icon: Icon(Icons.save, size: 18.0),
      onPressed: state._handleClickSaveButton,
    ),
  ];

  if (state._isEncFile == true && !Platform.isWindows) {
    actions.add(
      _ResultActionData(
        label: 'เปิด',
        icon: Icon(Icons.article_outlined, size: 18.0),
        onPressed: state._handleClickOpenButton,
      ),
    );
  } else {
    actions.add(
      _ResultActionData(
        label: 'อนุญาต',
        icon: Icon(Icons.contacts, size: 18.0),
        onPressed: state._pickEmailShare,
      ),
    );
  }

  if (state._isEncFile == true && Platform.isWindows) {
    actions.add(
      _ResultActionData(
        label: 'เปิด',
        icon: Icon(Icons.article_outlined, size: 18.0),
        onPressed: state._handleClickOpenButton,
      ),
    );
  } else {
    actions.add(
      _ResultActionData(
        label: 'แชร์',
        icon: Icon(Icons.share, size: 18.0),
        onPressed: state._handleClickShareButton,
      ),
    );
  }

  if (state._isEncFile == true) {
    actions.add(
      _ResultActionData(
        label: 'เข้ารหัส',
        icon: Icon(Icons.enhanced_encryption_outlined, size: 18.0),
        onPressed: state._goEncryption,
      ),
    );
  }

  actions.add(
    _ResultActionData(
      label: 'พิมพ์',
      icon: Icon(Icons.print, size: 18.0),
      onPressed: state._handlePrintingButton,
    ),
  );

  return actions;
}
