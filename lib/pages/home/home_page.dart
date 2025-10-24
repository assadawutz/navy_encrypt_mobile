library home_page;

import 'dart:io' show Directory, File, FileSystemEntity, Platform;
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
// import 'package:file_picker_cross/file_picker_cross.dart';
// import 'package:file_picker_cross/file_picker_cross.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:image_picker/image_picker.dart';
import 'package:is_first_run/is_first_run.dart';
import 'package:navy_encrypt/common/header_scaffold.dart';
import 'package:navy_encrypt/common/my_dialog.dart';
import 'package:navy_encrypt/common/my_state.dart';
import 'package:navy_encrypt/common/widget_view.dart';
import 'package:navy_encrypt/etc/constants.dart';
import 'package:navy_encrypt/etc/dimension_util.dart';
import 'package:navy_encrypt/etc/file_util.dart';
import 'package:navy_encrypt/core/io_helper.dart';
import 'package:navy_encrypt/core/perm_guard.dart';
import 'package:navy_encrypt/core/crypto_flow.dart';
import 'package:navy_encrypt/etc/utils.dart';
import 'package:navy_encrypt/pages/cloud_picker/cloud_picker_page.dart';
import 'package:navy_encrypt/pages/cloud_picker/google_drive.dart';
import 'package:navy_encrypt/pages/cloud_picker/local_drive.dart';
import 'package:navy_encrypt/pages/cloud_picker/onedrive.dart';
import 'package:navy_encrypt/pages/decryption/decryption_page.dart';
import 'package:navy_encrypt/pages/encryption/encryption_page.dart';
import 'package:navy_encrypt/pages/history/history_page.dart';
import 'package:navy_encrypt/pages/settings/settings_page.dart';
// import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;

part 'home_page_view.dart';
part 'home_page_view_win.dart';

class HomePage extends StatefulWidget {
  static const routeName = 'home';
  final String filePath;

  const HomePage({@required Key key, this.filePath}) : super(key: key);

  @override
  HomePageController createState() => HomePageController(filePath);
}

class HomePageController extends MyState<HomePage> {
  final ImagePicker _picker = ImagePicker();
  List<Map<String, dynamic>> _menuData;
  String filePath;
  drive.DriveApi _driveApi;

  final _googleSignIn = GoogleSignIn.standard(
    scopes: [
      'email',
      'https://www.googleapis.com/auth/drive',
    ],
  );

  HomePageController(this.filePath);

  static const int _maxFileSizeInBytes = CryptoFlow.maxFileSizeInBytes;

  @override
  Widget build(BuildContext context) {
    return isLandscapeLayout(context)
        ? _HomePageViewWin(this)
        : _HomePageView(this);
  }

  @override
  void initState() {
    super.initState();
    _initMenuData();
    // Future.delayed(
    //     Duration.zero, () => print('SCREEN RATIO: ${screenRatio(context)}'));

    if (filePath != null) {
      handleIntent(filePath);
      filePath = null;
    }

    // เปิดหน้า ตั้งค่าเมื่อเปิดใช้งานครั้งแรก
    WidgetsBinding.instance.addPostFrameCallback((_) {
      chkFirstRun();
    });
  }

  Future<void> _pickFile(BuildContext context) async {
    try {
      final granted = await PermGuard.ensurePickerAccess();
      if (!granted) {
        _showSnackBar('ยกเลิกการเลือกไฟล์');
        return;
      }

      final result = await FilePicker.platform.pickFiles(withData: true);
      if (result == null || result.files.isEmpty) {
        _showSnackBar('ยกเลิกการเลือกไฟล์');
        return;
      }

      final file = result.files.single;
      final size = file.size ?? file.bytes?.length;
      if (size != null && size > CryptoFlow.maxFileSizeInBytes) {
        _showSnackBar('ไฟล์มีขนาดเกิน 20MB');
        return;
      }

      File persisted;
      try {
        persisted = await IOHelper.persistPlatformFile(file);
      } catch (error) {
        debugPrint('❌ Failed to persist picked file: $error');
        _showSnackBar('เกิดข้อผิดพลาด: ${error.toString()}');
        return;
      }

      if (!_checkFileExtension(persisted.path)) {
        return;
      }

      if (!mounted) {
        return;
      }

      handleIntent(persisted.path, file.bytes);
    } catch (error) {
      debugPrint('❌ Error picking file: $error');
      _showSnackBar('เกิดข้อผิดพลาด: ${error.toString()}');
    }
  }

  void chkFirstRun() async {
    bool firstRun = await IsFirstRun.isFirstRun();
    if (firstRun) {
      Navigator.pushNamed(
        context,
        SettingsPage.routeName,
      );
    }
  }

  // called from main.dart
  Future<void> handleIntent(String filePath, [List<int> fileBytes]) async {
    if ((filePath == null || filePath.trim().isEmpty) &&
        (fileBytes == null || fileBytes.isEmpty)) {
      _showSnackBar('ไม่พบไฟล์');
      return;
    }

    Uint8List bytes;
    if (fileBytes != null && fileBytes.isNotEmpty) {
      bytes = Uint8List.fromList(fileBytes);
    }

    File resolvedFile;
    try {
      resolvedFile = await IOHelper.ensureFile(filePath, fallbackBytes: bytes);
    } catch (error) {
      _showSnackBar('เกิดข้อผิดพลาด: ${error.toString()}');
      return;
    }

    if (resolvedFile == null) {
      _showSnackBar('ไม่พบไฟล์');
      return;
    }

    if (!_checkFileExtension(resolvedFile.path)) {
      return;
    }

    final extension = p.extension(resolvedFile.path).toLowerCase();
    final routeToGo = extension == '.enc'
        ? DecryptionPage.routeName
        : EncryptionPage.routeName;

    if (!mounted) {
      return;
    }

    Future.delayed(
      Duration.zero,
      () {
        if (!mounted) {
          return;
        }
        Navigator.of(context).popUntil((route) => route.isFirst);
        Navigator.pushNamed(
          context,
          routeToGo,
          arguments: resolvedFile.path,
        );
      },
    );
  }

  void _initMenuData() {
    _menuData = [
      {
        'image': 'assets/images/ic_document.png',
        'text': Platform.isWindows ? 'ไฟล์ในเครื่อง' : 'ไฟล์ในเครื่อง',
        'onClick': _pickFromFileSystem,
      },
      {
        'image': 'assets/images/ic_camera.png',
        'text': 'กล้อง',
        'onClick': Platform.isWindows ? null : _pickFromCamera,
      },
      {
        'image': 'assets/images/ic_gallery.png',
        'text': Platform.isWindows ? 'รูปภาพ' : 'คลังภาพ',
        'onClick': _pickFromGallery,
      },
      {
        'image': 'assets/images/ic_google_drive.png',
        'text': 'Google Drive',
        'onClick': _doPickFromGoogleDrive,
      },
      {
        'image': 'assets/images/ic_onedrive_new.png',
        'text': 'OneDrive',
        'onClick': _pickFromOneDrive,
      },
      {
        'image': 'assets/images/ic_history.png',
        'text': 'ประวัติ',
        'onClick': (BuildContext context) {
          Navigator.pushNamed(
            context,
            HistoryPage.routeName,
          );
        },
      },
    ];
  }

  void _showSnackBar(String message) {
    if (!mounted || message == null || message.isEmpty) {
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  _pickFromFileSystem(BuildContext context) async {
    logOneLineWithBorderDouble(await FileUtil.getImageDirPath());

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return MyDialog.buildPickerDialog(
          headerImage: Image.asset('assets/images/ic_document.png',
              width: Constants.LIST_DIALOG_HEADER_IMAGE_SIZE),
          items: [
            DialogTileData(
              label:
                  'โฟลเดอร์ของแอป${Platform.isWindows ? ' ' : '\n'}(App\'s Documents Folder)',
              /*image: Image.asset(
                'assets/images/ic_document.png',
                width: Constants.LIST_DIALOG_ICON_SIZE,
                height: Constants.LIST_DIALOG_ICON_SIZE,
              ),*/
              image: const Icon(
                FontAwesomeIcons.solidFolderOpen,
                size: Constants.LIST_DIALOG_ICON_SIZE,
                color: Constants.LIST_DIALOG_ICON_COLOR,
              ),
              onClick: () async {
                Navigator.of(context).pop();
                Navigator.pushNamed(
                  context,
                  CloudPickerPage.routeName,
                  arguments: CloudPickerPageArg(
                      cloudDrive: LocalDrive(
                        CloudPickerMode.file,
                        (await FileUtil.getDocDir()).path,
                      ),
                      title: 'โฟลเดอร์ของแอป',
                      headerImagePath: 'assets/images/ic_document.png',
                      rootName: 'App\'s Folder'),
                );
              },
            ),
            // if (Platform.isIOS || Platform.isWindows)
            DialogTileData(
              label:
                  'โฟลเดอร์อื่นๆ${Platform.isWindows ? ' ' : '\n'}(เลือกจาก System Dialog)',
              image: const Icon(
                FontAwesomeIcons.sdCard,
                size: Constants.LIST_DIALOG_ICON_SIZE,
                color: Constants.LIST_DIALOG_ICON_COLOR,
              ),
              onClick: () async {
                Navigator.of(context).pop();

                await _openSystemPicker(context);
                // await FileHelper.pickAnyFile(context); // ถ้าต้องออกนอก temp dir
              },
            ),
          ],
        );
      },
    );
  }

  _openSystemPicker2(BuildContext context,
      {bool pickImage = false, bool pickVideo = false}) async {
    File _file;

    FilePickerResult result = await FilePicker.platform.pickFiles();

    if (result != null) {
      final file = File(result.files.single.path);
      _file = file;
      setState(() {
        print("fieleee ${_file.path}");
      });
    } else {
      // User canceled the picker
      // You can show snackbar or fluttertoast
      // here like this to show warning to user
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Please select file'),
      ));
    }
  }

  //
  Future<void> _openSystemPicker(BuildContext context,
      {bool pickImage = false, bool pickVideo = false}) async {
    if (Platform.isWindows && pickImage) {
      _showSnackBar('Windows ไม่รองรับกล้อง');
      return;
    }

    try {
      final granted = await PermGuard.ensurePickerAccess();
      if (!granted) {
        _showSnackBar('ยกเลิกการเลือกไฟล์');
        return;
      }

      File pickedFile;
      if (pickImage) {
        final XFile image =
            await ImagePicker().pickImage(source: ImageSource.gallery);
        if (image == null) {
          _showSnackBar('ยกเลิกการเลือกไฟล์');
          return;
        }
        pickedFile = File(image.path);
      } else if (pickVideo) {
        final XFile video =
            await ImagePicker().pickVideo(source: ImageSource.gallery);
        if (video == null) {
          _showSnackBar('ยกเลิกการเลือกไฟล์');
          return;
        }
        pickedFile = File(video.path);
      } else {
        final result = await FilePicker.platform.pickFiles(
          type: Platform.isWindows ? FileType.custom : FileType.any,
          allowedExtensions: Platform.isWindows
              ? Constants.selectableFileTypeList
                  .map((e) => e.fileExtension)
                  .toList()
              : null,
        );

        if (result == null || result.files.single.path == null) {
          _showSnackBar('ยกเลิกการเลือกไฟล์');
          return;
        }
        pickedFile = File(result.files.single.path);
      }

      if (pickedFile == null) {
        _showSnackBar('ไม่พบไฟล์');
        return;
      }

      final size = await pickedFile.length();
      if (size > _maxFileSizeInBytes) {
        _showSnackBar('ไฟล์มีขนาดเกิน 20MB');
        return;
      }

      final filePath = pickedFile.path;
      if (!_checkFileExtension(filePath)) {
        return;
      }

      if (!mounted) {
        return;
      }

      handleIntent(filePath);
    } catch (error) {
      _showSnackBar('เกิดข้อผิดพลาด: ${error.toString()}');
    }
  }

  _pickFromCamera(BuildContext context) async {
    if (Platform.isWindows) {
      _showSnackBar('Windows ไม่รองรับกล้อง');
      return;
    }

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return MyDialog.buildPickerDialog(
            headerImage: Image.asset('assets/images/ic_camera.png',
                width: Constants.LIST_DIALOG_HEADER_IMAGE_SIZE),
            items: [
              DialogTileData(
                label: 'ถ่ายภาพนิ่ง',
                image: const Icon(
                  Icons.camera_alt,
                  size: Constants.LIST_DIALOG_ICON_SIZE,
                  color: Constants.LIST_DIALOG_ICON_COLOR,
                ),
                onClick: () {
                  _pickMediaFile(
                      context, _picker.pickImage, ImageSource.camera);
                  Navigator.pop(context);
                },
              ),
              DialogTileData(
                label: 'ถ่ายวิดีโอ',
                image: const Icon(
                  Icons.videocam_rounded,
                  size: Constants.LIST_DIALOG_ICON_SIZE,
                  color: Constants.LIST_DIALOG_ICON_COLOR,
                ),
                onClick: () {
                  _pickMediaFile(
                      context, _picker.pickVideo, ImageSource.camera);
                  Navigator.pop(context);
                },
              ),
            ]);
      },
    );
  }

  _pickFromGallery(BuildContext context) async {
// Windows
    if (Platform.isWindows) {
      Navigator.pushNamed(
        context,
        CloudPickerPage.routeName,
        arguments: CloudPickerPageArg(
          cloudDrive: LocalDrive(
            CloudPickerMode.file,
            (await FileUtil.getImageDirPath()),
          ),
          title: 'รูปภาพ',
          headerImagePath: 'assets/images/ic_gallery.png',
          rootName: 'Pictures',
        ),
      );
    }
// Android, iOS
    else {
      showDialog(
        context: context,
        builder: (BuildContext dialogContext) {
          return MyDialog.buildPickerDialog(
              headerImage: Image.asset('assets/images/ic_gallery.png',
                  width: Constants.LIST_DIALOG_HEADER_IMAGE_SIZE),
              items: [
                DialogTileData(
                  label: 'เลือกรูปภาพ',
                  image: const Icon(
                    Icons.image,
                    size: Constants.LIST_DIALOG_ICON_SIZE,
                    color: Constants.LIST_DIALOG_ICON_COLOR,
                  ),
                  onClick: () {
                    Navigator.pop(context);

                    Future.delayed(
                        Duration.zero,
                        () => _pickMediaFile(
                            context, _picker.pickImage, ImageSource.gallery));
                  },
                ),
                DialogTileData(
                  label: 'เลือกวิดีโอ',
                  image: const Icon(
                    Icons.video_library,
                    size: Constants.LIST_DIALOG_ICON_SIZE,
                    color: Constants.LIST_DIALOG_ICON_COLOR,
                  ),
                  onClick: () {
                    Navigator.pop(context);
                    Future.delayed(
                        Duration.zero,
                        () => _pickMediaFile(
                            context, _picker.pickVideo, ImageSource.gallery));
                  },
                ),
              ]);
        },
      );
    }
  }

  // _pickFromGoogleDrive(BuildContext context) async {
  //   showMaterialModalBottomSheet(
  //     context: context,
  //     shape: RoundedRectangleBorder(
  //       borderRadius: BorderRadius.only(
  //         topLeft: Radius.circular(10.0),
  //         topRight: Radius.circular(10.0),
  //       ),
  //     ),
  //     builder: (bottomSheetContext) => Container(
  //       height: 120.0,
  //       child: Center(
  //         child: Container(
  //           height: 40.0,
  //           width: 180.0,
  //           child: SignInButton(
  //             Buttons.GoogleDark,
  //             padding: EdgeInsets.all(2.0),
  //             mini: false,
  //             onPressed: () {
  //               Navigator.pop(bottomSheetContext);
  //               _doPickFromGoogleDrive(context);
  //             },
  //           ),
  //         ),
  //       ),
  //     ),
  //   );
  // }

  // _doPickFromGoogleDrive(BuildContext context) async {
  //   isLoading = true;
  //   loadingMessage = 'กำลังลงทะเบียนเข้าใช้งาน Google Drive';
  //   Future.delayed(Duration(seconds: 2), () {
  //     isLoading = false;
  //   });
  //
  //   var googleDrive = GoogleDrive(CloudPickerMode.file);
  //   var signInSuccess = Platform.isWindows
  //       ? await googleDrive.signInWithOAuth2()
  //       : await googleDrive.signIn();
  //
  //   if (signInSuccess) {
  //     Navigator.pushNamed(
  //       context,
  //       CloudPickerPage.routeName,
  //       arguments: CloudPickerPageArg(
  //           cloudDrive: googleDrive,
  //           title: 'Google Drive',
  //           headerImagePath: 'assets/images/ic_google_drive.png',
  //           rootName: 'Drive'),
  //     );
  //   } else {
  //     showOkDialog(
  //       context,
  //       'ผิดพลาด',
  //       textContent: 'ไม่สามารถลงทะเบียนเข้าใช้งาน Google Drive ได้',
  //     );
  //   }
  //   //isLoading = false;
  // }

  Future<void> _doPickFromGoogleDrive(BuildContext context) async {
    if (!mounted) {
      return;
    }

    isLoading = true;
    loadingMessage = 'กำลังลงทะเบียนเข้าใช้งาน Google Drive';

    final googleDrive = GoogleDrive(CloudPickerMode.file);
    try {
      final signInSuccess = Platform.isWindows || Platform.isMacOS
          ? await googleDrive.signInWithOAuth2()
          : await googleDrive.signIn();

      if (!mounted) {
        return;
      }

      if (signInSuccess == true) {
        Navigator.pushNamed(
          context,
          CloudPickerPage.routeName,
          arguments: CloudPickerPageArg(
            cloudDrive: googleDrive,
            title: 'Google Drive',
            headerImagePath: 'assets/images/ic_google_drive.png',
            rootName: 'Drive',
          ),
        );
      } else {
        _showSnackBar('ยกเลิกการเลือกไฟล์');
      }
    } catch (error, stackTrace) {
      logOneLineWithBorderDouble(
          'Failed to register Google Drive session: $error\n$stackTrace');
      if (!mounted) {
        return;
      }
      _showSnackBar('เกิดข้อผิดพลาด: ${error.toString()}');
    } finally {
      if (mounted) {
        isLoading = false;
      }
    }
  }

  Future<bool> signIn() async {
    GoogleSignInAccount account = await _googleSignIn.signIn();
    if (account != null) {
      final authHeaders = await account.authHeaders; // token อยู่ใน authHeaders
      final authenticateClient = GoogleAuthClient(authHeaders);
      _driveApi = drive.DriveApi(authenticateClient);
      return true;
    }
    return false;
  }

  _pickFromOneDrive(BuildContext context) async {
    /*if (Platform.isWindows) {
      var oneDrive = OneDrive(CloudPickerMode.file);
      var signInSuccess = await oneDrive.signInWithOAuth2();

      showOkDialog(context, 'SIGN IN - $signInSuccess');

      return;
    }*/

    isLoading = true;
    loadingMessage = 'กำลังลงทะเบียนเข้าใช้งาน OneDrive';

    var oneDrive = OneDrive(CloudPickerMode.file);
    try {
      var signInSuccess = Platform.isWindows
          ? await oneDrive.signInWithOAuth2()
          : await oneDrive.signIn();

      if (signInSuccess) {
        Navigator.pushNamed(
          context,
          CloudPickerPage.routeName,
          arguments: CloudPickerPageArg(
            cloudDrive: oneDrive,
            title: 'OneDrive',
            headerImagePath: 'assets/images/ic_onedrive_new.png',
            rootName: 'Drive',
          ),
        );
      } else {
        _showSnackBar('ยกเลิกการเลือกไฟล์');
      }
    } catch (error) {
      _showSnackBar('เกิดข้อผิดพลาด: ${error.toString()}');
    } finally {
      if (mounted) {
        isLoading = false;
      }
    }
    //isLoading = false;

    /*final success = await onedrive.connect();

    if (success) {
      logOneLineWithBorderDouble('YES');
      showOkDialog(context, 'สำเร็จ',
          textContent:
              'เข้าสู่ระบบด้วย Microsoft account สำเร็จ\nการเชื่อมต่อกับ OneDrive อยู่ระหว่างการพัฒนา');
      // Download files
      //final txtBytes = await onedrive.pull("/xxx/xxx.txt");

      // Upload files
      //await onedrive.push(txtBytes!, "/xxx/xxx.txt");
    } else {
      logOneLineWithBorderDouble('NO');
    }*/
  }

  _checkFileExtension(String filePath) {
    final extensionList = Constants.selectableFileTypeList
        .map((fileType) => fileType.fileExtension)
        .toList();
    //logOneLineWithBorderSingle('EXTENSION LIST: $extensionList');

    var extension = p.extension(filePath);
    if (extension == null || extension.trim().isEmpty) {
      showOkDialog(
        context,
        'ผิดพลาด',
        textContent: 'ไฟล์ที่เลือกไม่มีนามสกุล (extension)',
      );
      return false;
    } else if (!extensionList.contains(extension.substring(1).toLowerCase())) {
      showOkDialog(
        context,
        'ผิดพลาด',
        textContent:
            'แอปไม่รองรับการเข้ารหัสไฟล์ประเภท ${extension.substring(1).toUpperCase()}\n(ไฟล์ \'${p.basename(filePath)}\')',
      );
      return false;
    } else {
      //_test(filePath);
      return true;
    }
  }

  _pickMediaFile(
      BuildContext context, Function pickMethod, ImageSource source) async {
    if (Platform.isWindows) {
      _showSnackBar('Windows ไม่รองรับกล้อง');
      return;
    }

    if (!mounted) {
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final XFile selectedFile = await pickMethod(source: source);

      if (selectedFile == null) {
        if (mounted) {
          setState(() {
            isLoading = false;
          });
          _showSnackBar('ยกเลิกการเลือกไฟล์');
        }
        return;
      }

      final file = File(selectedFile.path);
      if (!await file.exists()) {
        if (mounted) {
          setState(() {
            isLoading = false;
          });
        }
        _showSnackBar('ไม่พบไฟล์');
        return;
      }

      final size = await file.length();
      if (size > _maxFileSizeInBytes) {
        if (mounted) {
          setState(() {
            isLoading = false;
          });
        }
        _showSnackBar('ไฟล์มีขนาดเกิน 20MB');
        return;
      }

      if (!_checkFileExtension(selectedFile.path)) {
        if (mounted) {
          setState(() {
            isLoading = false;
          });
        }
        return;
      }

      final bytes = await file.readAsBytes();

      if (!mounted) {
        return;
      }

      setState(() {
        isLoading = false;
      });

      handleIntent(selectedFile.path, bytes);
    } catch (error) {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
      _showSnackBar('เกิดข้อผิดพลาด: ${error.toString()}');
    }
  }

// Future<PackageInfo> _getPackageInfo() async {
//   return await PackageInfo.fromPlatform();
//
//   /*String appName = packageInfo.appName;
//   String packageName = packageInfo.packageName;
//   String version = packageInfo.version;
//   String buildNumber = packageInfo.buildNumber;*/
// }
}
