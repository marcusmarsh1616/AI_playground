#region [CSharp Code]

$Assemblies = ("System.DirectoryServices, Version=2.0.0.0, Culture=neutral, PublicKeyToken=B03F5F7F11D50A3A")

$PSADT = @"
using System;
using System.Text;
using System.Collections;
using System.ComponentModel;
using System.DirectoryServices;
using System.Security.Principal;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Text.RegularExpressions;
using FILETIME = System.Runtime.InteropServices.ComTypes.FILETIME;

namespace PSADT
{
	public class Msi
	{
		enum LoadLibraryFlags : int
		{
			DONT_RESOLVE_DLL_REFERENCES 		= 0x00000001,
			LOAD_IGNORE_CODE_AUTHZ_LEVEL		= 0x00000010,
			LOAD_LIBRARY_AS_DATAFILE    		= 0x00000002,
			LOAD_LIBRARY_AS_DATAFILE_EXCLUSIVE	= 0x00000040,
			LOAD_LIBRARY_AS_IMAGE_RESOURCE  	= 0x00000020,
			LOAD_WITH_ALTERED_SEARCH_PATH 		= 0x00000008
		}
		
		[DllImport("kernel32.dll", CharSet = CharSet.Auto, SetLastError = false)]
		static extern IntPtr LoadLibraryEx(string lpFileName, IntPtr hFile, LoadLibraryFlags dwFlags);
		
		[DllImport("user32.dll", CharSet = CharSet.Auto, SetLastError = false)]
		static extern int LoadString(IntPtr hInstance, int uID, StringBuilder lpBuffer, int nBufferMax);
		
		// Get MSI exit code message from msimsg.dll resource dll
		public static string GetMessageFromMsiExitCode(int errCode)
		{
			IntPtr hModuleInstance = LoadLibraryEx("msimsg.dll", IntPtr.Zero, LoadLibraryFlags.LOAD_LIBRARY_AS_DATAFILE);
			
			StringBuilder sb = new StringBuilder(255);
			LoadString(hModuleInstance, errCode, sb, sb.Capacity + 1);
			
			return sb.ToString();
		}
	}
	
	public class Explorer
	{
		private static readonly IntPtr HWND_BROADCAST = new IntPtr(0xffff);
		private const int WM_SETTINGCHANGE = 0x1a;
		private const int SMTO_ABORTIFHUNG = 0x0002;
		
		[DllImport("user32.dll", CharSet = CharSet.Auto, SetLastError = false)]
		static extern bool SendNotifyMessage(IntPtr hWnd, int Msg, IntPtr wParam, IntPtr lParam);
		
		[DllImport("user32.dll", CharSet = CharSet.Auto, SetLastError = false)]
		private static extern IntPtr SendMessageTimeout(IntPtr hWnd, int Msg, IntPtr wParam, string lParam, int fuFlags, int uTimeout, IntPtr lpdwResult);
		
		[DllImport("shell32.dll", CharSet = CharSet.Auto, SetLastError = false)]
		private static extern int SHChangeNotify(int eventId, int flags, IntPtr item1, IntPtr item2);
		
		public static void RefreshDesktopAndEnvironmentVariables()
		{
			// Update desktop icons
			SHChangeNotify(0x8000000, 0x1000, IntPtr.Zero, IntPtr.Zero);
			SendMessageTimeout(HWND_BROADCAST, WM_SETTINGCHANGE, IntPtr.Zero, null, SMTO_ABORTIFHUNG, 100, IntPtr.Zero);
			// Update environment variables
			SendMessageTimeout(HWND_BROADCAST, WM_SETTINGCHANGE, IntPtr.Zero, "Environment", SMTO_ABORTIFHUNG, 100, IntPtr.Zero);
		}
	}
	
	public sealed class FileVerb
	{
		[DllImport("user32.dll", CharSet = CharSet.Auto, SetLastError = false)]
		public static extern int LoadString(IntPtr h, int id, StringBuilder sb, int maxBuffer);
		
		[DllImport("kernel32.dll", CharSet = CharSet.Auto, SetLastError = false)]
		public static extern IntPtr LoadLibrary(string s);
		
		public static string GetPinVerb(int VerbId)
		{
			IntPtr hShell32 = LoadLibrary("shell32.dll");
			const int nChars  = 255;
			StringBuilder Buff = new StringBuilder("", nChars);
						
			LoadString(hShell32, VerbId, Buff, Buff.Capacity);
			return Buff.ToString();
		}
	}
	
	public sealed class IniFile
	{
		[DllImport("kernel32.dll", CharSet = CharSet.Auto, SetLastError = false)]
		public static extern int GetPrivateProfileString(string lpAppName, string lpKeyName, string lpDefault, StringBuilder lpReturnedString, int nSize, string lpFileName);
		
		[DllImport("kernel32.dll", CharSet = CharSet.Auto, SetLastError = false)]
		[return: MarshalAs(UnmanagedType.Bool)]
		public static extern bool WritePrivateProfileString(string lpAppName, string lpKeyName, StringBuilder lpString, string lpFileName);
		
		public static string GetIniValue(string section, string key, string filepath)
		{
			string sDefault	= "";
			const int  nChars  = 1024;
			StringBuilder Buff = new StringBuilder(nChars);
					
			GetPrivateProfileString(section, key, sDefault, Buff, Buff.Capacity, filepath);
			return Buff.ToString();
		}
		
		public static void SetIniValue(string section, string key, StringBuilder value, string filepath)
		{
			WritePrivateProfileString(section, key, value, filepath);
		}
	}
	
	public class UiAutomation
	{
		public enum GetWindow_Cmd : int
		{
			GW_HWNDFIRST    = 0,
			GW_HWNDLAST     = 1,
			GW_HWNDNEXT     = 2,
			GW_HWNDPREV     = 3,
			GW_OWNER        = 4,
			GW_CHILD        = 5,
			GW_ENABLEDPOPUP = 6
		}
		
		public enum ShowWindowEnum
		{
			Hide                    = 0,
			ShowNormal              = 1,
			ShowMinimized           = 2,
			ShowMaximized           = 3,
			Maximize                = 3,
			ShowNormalNoActivate    = 4,
			Show                    = 5,
			Minimize                = 6,
			ShowMinNoActivate       = 7,
			ShowNoActivate          = 8,
			Restore                 = 9,
			ShowDefault             = 10,
			ForceMinimized          = 11
		}
		
		public enum UserNotificationState
		{
			// http://msdn.microsoft.com/en-us/library/bb762533(v=vs.85).aspx
			ScreenSaverOrLockedOrFastUserSwitching		=1, // A screen saver is displayed, the machine is locked, or a nonactive Fast User Switching session is in progress.
			FullScreenOrPresentationModeOrLoginScreen	=2, // A full-screen application is running or Presentation Settings are applied. Presentation Settings allow a user to put their machine into a state fit for an uninterrupted presentation, such as a set of PowerPoint slides, with a single click. Also returns this state if machine is at the login screen.
			RunningDirect3DFullScreen					=3, // A full-screen, exclusive mode, Direct3D application is running.
			PresentationMode 							=4, // The user has activated Windows presentation settings to block notifications and pop-up messages.
			AcceptsNotifications						=5, // None of the other states are found, notifications can be freely sent.
			QuietTime									=6, // Introduced in Windows 7. The current user is in "quiet time", which is the first hour after a new user logs into his or her account for the first time.
			WindowsStoreAppRunning						=7  // Introduced in Windows 8. A Windows Store app is running.
		}
		
		// Only for Vista or above
		[DllImport("shell32.dll", CharSet = CharSet.Auto, SetLastError = false)]
		static extern int SHQueryUserNotificationState(out UserNotificationState pquns);
		
		[DllImport("user32.dll", CharSet = CharSet.Auto, SetLastError = false)]
		[return: MarshalAs(UnmanagedType.Bool)]
		public static extern bool EnumWindows(EnumWindowsProcD lpEnumFunc, ref IntPtr lParam);
		
		[DllImport("user32.dll", CharSet = CharSet.Auto, SetLastError = false)]
		public static extern int GetWindowText(IntPtr hWnd, StringBuilder lpString, int nMaxCount);
		
		[DllImport("user32.dll", CharSet = CharSet.Auto, SetLastError = false)]
		public static extern int GetWindowTextLength(IntPtr hWnd);
		
		[DllImport("user32.dll", CharSet = CharSet.Auto, SetLastError = false)]
		private static extern IntPtr GetDesktopWindow();
		
		[DllImport("user32.dll", CharSet = CharSet.Auto, SetLastError = false)]
		private static extern IntPtr GetShellWindow();
		
		[DllImport("user32.dll", CharSet = CharSet.Auto, SetLastError = false)]
		[return: MarshalAs(UnmanagedType.Bool)]
		public static extern bool IsWindowEnabled(IntPtr hWnd);
		
		[DllImport("user32.dll", CharSet = CharSet.Auto, SetLastError = false)]
		public static extern bool IsWindowVisible(IntPtr hWnd);
		
		[DllImport("user32.dll", CharSet = CharSet.Auto, SetLastError = false)]
		[return: MarshalAs(UnmanagedType.Bool)]
		public static extern bool IsIconic(IntPtr hWnd);
		
		[DllImport("user32.dll", CharSet = CharSet.Auto, SetLastError = false)]
		[return: MarshalAs(UnmanagedType.Bool)]
		public static extern bool ShowWindow(IntPtr hWnd, ShowWindowEnum flags);
		
		[DllImport("user32.dll", CharSet = CharSet.Auto, SetLastError = false)]
		public static extern IntPtr SetActiveWindow(IntPtr hwnd);
		
		[DllImport("user32.dll", CharSet = CharSet.Auto, SetLastError = false)]
		[return: MarshalAs(UnmanagedType.Bool)]
		public static extern bool SetForegroundWindow(IntPtr hWnd);
		
		[DllImport("user32.dll", CharSet = CharSet.Auto, SetLastError = false)]
		public static extern IntPtr GetForegroundWindow();
		
		[DllImport("user32.dll", CharSet = CharSet.Auto, SetLastError = false)]
		public static extern IntPtr SetFocus(IntPtr hWnd);
		
		[DllImport("user32.dll", CharSet = CharSet.Auto, SetLastError = false)]
		public static extern bool BringWindowToTop(IntPtr hWnd);
		
		[DllImport("user32.dll", CharSet = CharSet.Auto, SetLastError = false)]
		public static extern int GetWindowThreadProcessId(IntPtr hWnd, out int lpdwProcessId);
		
		[DllImport("kernel32.dll", CharSet = CharSet.Auto, SetLastError = false)]
		public static extern int GetCurrentThreadId();
		
		[DllImport("user32.dll", CharSet = CharSet.Auto, SetLastError = false)]
		public static extern bool AttachThreadInput(int idAttach, int idAttachTo, bool fAttach);
		
		[DllImport("user32.dll", EntryPoint = "GetWindowLong", CharSet = CharSet.Auto, SetLastError = false)]
		public static extern IntPtr GetWindowLong32(IntPtr hWnd, int nIndex);
		
		[DllImport("user32.dll", EntryPoint = "GetWindowLongPtr", CharSet = CharSet.Auto, SetLastError = false)]
		public static extern IntPtr GetWindowLongPtr64(IntPtr hWnd, int nIndex);
		
		public delegate bool EnumWindowsProcD(IntPtr hWnd, ref IntPtr lItems);
		
		public static bool EnumWindowsProc(IntPtr hWnd, ref IntPtr lItems)
		{
			if (hWnd != IntPtr.Zero)
			{
				GCHandle hItems = GCHandle.FromIntPtr(lItems);
				List<IntPtr> items = hItems.Target as List<IntPtr>;
				items.Add(hWnd);
				return true;
			}
			else
			{
				return false;
			}
		}
		
		public static List<IntPtr> EnumWindows()
		{
			try
			{
				List<IntPtr> items = new List<IntPtr>();
				EnumWindowsProcD CallBackPtr = new EnumWindowsProcD(EnumWindowsProc);
				GCHandle hItems = GCHandle.Alloc(items);
				IntPtr lItems = GCHandle.ToIntPtr(hItems);
				EnumWindows(CallBackPtr, ref lItems);
				return items;
			}
			catch (Exception ex)
			{
				throw new Exception("An error occured during window enumeration: " + ex.Message);
			}
		}
		
		public static string GetWindowText(IntPtr hWnd)
		{
			int iTextLength = GetWindowTextLength(hWnd);
			if (iTextLength > 0)
			{
				StringBuilder sb = new StringBuilder(iTextLength);
				GetWindowText(hWnd, sb, iTextLength + 1);
				return sb.ToString();
			}
			else
			{
				return String.Empty;
			}
		}
		
		public static bool BringWindowToFront(IntPtr windowHandle)
		{
			bool breturn = false;
			if (IsIconic(windowHandle))
			{
				// Show minimized window because SetForegroundWindow does not work for minimized windows
				ShowWindow(windowHandle, ShowWindowEnum.ShowMaximized);
			}
			
			int lpdwProcessId;
			int windowThreadProcessId = GetWindowThreadProcessId(GetForegroundWindow(), out lpdwProcessId);
			int currentThreadId = GetCurrentThreadId();
			AttachThreadInput(windowThreadProcessId, currentThreadId, true);
			
			BringWindowToTop(windowHandle);
			breturn = SetForegroundWindow(windowHandle);
			SetActiveWindow(windowHandle);
			SetFocus(windowHandle);
			
			AttachThreadInput(windowThreadProcessId, currentThreadId, false);
			return breturn;
		}
		
		public static int GetWindowThreadProcessId(IntPtr windowHandle)
		{
			int processID = 0;
			GetWindowThreadProcessId(windowHandle, out processID);
			return processID;
		}
		
		public static IntPtr GetWindowLong(IntPtr hWnd, int nIndex)
		{
			if (IntPtr.Size == 4)
			{
				return GetWindowLong32(hWnd, nIndex);
			}
			return GetWindowLongPtr64(hWnd, nIndex);
		}
		
		public static string GetUserNotificationState()
		{
			// Only works for Windows Vista or higher
			UserNotificationState state;
			int returnVal = SHQueryUserNotificationState(out state);
			return state.ToString();
		}
	}
	
	public class QueryUser
	{
		[DllImport("wtsapi32.dll", CharSet = CharSet.Auto, SetLastError = false)]
		public static extern IntPtr WTSOpenServer(string pServerName);
		
		[DllImport("wtsapi32.dll", CharSet = CharSet.Auto, SetLastError = false)]
		public static extern void WTSCloseServer(IntPtr hServer);
		
		[DllImport("wtsapi32.dll", CharSet = CharSet.Ansi, SetLastError = false)]
		public static extern bool WTSQuerySessionInformation(IntPtr hServer, int sessionId, WTS_INFO_CLASS wtsInfoClass, out IntPtr pBuffer, out int pBytesReturned);
		
		[DllImport("wtsapi32.dll", CharSet = CharSet.Ansi, SetLastError = false)]
		public static extern int WTSEnumerateSessions(IntPtr hServer, int Reserved, int Version, out IntPtr pSessionInfo, out int pCount);
		
		[DllImport("wtsapi32.dll", CharSet = CharSet.Auto, SetLastError = false)]
		public static extern void WTSFreeMemory(IntPtr pMemory);
		
		[DllImport("winsta.dll", CharSet = CharSet.Auto, SetLastError = false)]
		public static extern int WinStationQueryInformation(IntPtr hServer, int sessionId, int information, ref WINSTATIONINFORMATIONW pBuffer, int bufferLength, ref int returnedLength);
		
		[DllImport("kernel32.dll", CharSet = CharSet.Auto, SetLastError = false)]
		public static extern int GetCurrentProcessId();
		
		[DllImport("kernel32.dll", CharSet = CharSet.Auto, SetLastError = false)]
		public static extern bool ProcessIdToSessionId(int processId, ref int pSessionId);
		
		public class TerminalSessionData
		{
			public int SessionId;
			public string ConnectionState;
			public string SessionName;
			public bool IsUserSession;
			public TerminalSessionData(int sessionId, string connState, string sessionName, bool isUserSession)
			{
				SessionId = sessionId;
				ConnectionState = connState;
				SessionName = sessionName;
				IsUserSession = isUserSession;
			}
		}
		
		public class TerminalSessionInfo
		{
			public string NTAccount;
			public string SID;
			public string UserName;
			public string DomainName;
			public int SessionId;
			public string SessionName;
			public string ConnectState;
			public bool IsCurrentSession;
			public bool IsConsoleSession;
			public bool IsActiveUserSession;
			public bool IsUserSession;
			public bool IsRdpSession;
			public bool IsLocalAdmin;
			public DateTime? LogonTime;
			public TimeSpan? IdleTime;
			public DateTime? DisconnectTime;
			public string ClientName;
			public string ClientProtocolType;
			public string ClientDirectory;
			public int ClientBuildNumber;
		}
		
		[StructLayout(LayoutKind.Sequential)]
		private struct WTS_SESSION_INFO
		{
			public Int32 SessionId;
			[MarshalAs(UnmanagedType.LPStr)]
			public string SessionName;
			public WTS_CONNECTSTATE_CLASS State;
		}
		
		[StructLayout(LayoutKind.Sequential)]
		public struct WINSTATIONINFORMATIONW
		{
			[MarshalAs(UnmanagedType.ByValArray, SizeConst = 70)]
			private byte[] Reserved1;
			public int SessionId;
			[MarshalAs(UnmanagedType.ByValArray, SizeConst = 4)]
			private byte[] Reserved2;
			public FILETIME ConnectTime;
			public FILETIME DisconnectTime;
			public FILETIME LastInputTime;
			public FILETIME LoginTime;
			[MarshalAs(UnmanagedType.ByValArray, SizeConst = 1096)]
			private byte[] Reserved3;
			public FILETIME CurrentTime;
		}
		
		public enum WINSTATIONINFOCLASS
		{
			WinStationInformation = 8
		}
		
		public enum WTS_CONNECTSTATE_CLASS
		{
			Active,
			Connected,
			ConnectQuery,
			Shadow,
			Disconnected,
			Idle,
			Listen,
			Reset,
			Down,
			Init
		}
		
		public enum WTS_INFO_CLASS
		{
			SessionId=4,
			UserName,
			SessionName,
			DomainName,
			ConnectState,
			ClientBuildNumber,
			ClientName,
			ClientDirectory,
			ClientProtocolType=16
		}
		
		private static IntPtr OpenServer(string Name)
		{
			IntPtr server = WTSOpenServer(Name);
			return server;
		}
		
		private static void CloseServer(IntPtr ServerHandle)
		{
			WTSCloseServer(ServerHandle);
		}
		
		private static IList<T> PtrToStructureList<T>(IntPtr ppList, int count) where T : struct
		{
			List<T> result = new List<T>();
			long pointer = ppList.ToInt64();
			int sizeOf = Marshal.SizeOf(typeof(T));
			
			for (int index = 0; index < count; index++)
			{
				T item = (T) Marshal.PtrToStructure(new IntPtr(pointer), typeof(T));
				result.Add(item);
				pointer += sizeOf;
			}
			return result;
		}
		
		public static DateTime? FileTimeToDateTime(FILETIME ft)
		{
			if (ft.dwHighDateTime == 0 && ft.dwLowDateTime == 0)
			{
				return null;
			}
			long hFT = (((long) ft.dwHighDateTime) << 32) + ft.dwLowDateTime;
			return DateTime.FromFileTime(hFT);
		}
		
		public static WINSTATIONINFORMATIONW GetWinStationInformation(IntPtr server, int sessionId)
		{
			int retLen = 0;
			WINSTATIONINFORMATIONW wsInfo = new WINSTATIONINFORMATIONW();
			WinStationQueryInformation(server, sessionId, (int) WINSTATIONINFOCLASS.WinStationInformation, ref wsInfo, Marshal.SizeOf(typeof(WINSTATIONINFORMATIONW)), ref retLen);
			return wsInfo;
		}
		
		public static TerminalSessionData[] ListSessions(string ServerName)
		{
			IntPtr server = IntPtr.Zero;
			if (ServerName == "localhost" || ServerName == String.Empty)
			{
				ServerName = Environment.MachineName;
			}
			
			List<TerminalSessionData> results = new List<TerminalSessionData>();
			
			try
			{
				server = OpenServer(ServerName);
				IntPtr ppSessionInfo = IntPtr.Zero;
				int count;
				bool _isUserSession = false;
				IList<WTS_SESSION_INFO> sessionsInfo;
				
				if (WTSEnumerateSessions(server, 0, 1, out ppSessionInfo, out count) == 0)
				{
					throw new Win32Exception();
				}
				
				try
				{
					sessionsInfo = PtrToStructureList<WTS_SESSION_INFO>(ppSessionInfo, count);
				}
				finally
				{
					WTSFreeMemory(ppSessionInfo);
				}
				
				foreach (WTS_SESSION_INFO sessionInfo in sessionsInfo)
				{
					if (sessionInfo.SessionName != "Services" && sessionInfo.SessionName != "RDP-Tcp")
					{
						_isUserSession = true;
					}
					results.Add(new TerminalSessionData(sessionInfo.SessionId, sessionInfo.State.ToString(), sessionInfo.SessionName, _isUserSession));
					_isUserSession = false;
				}
			}
			finally
			{
				CloseServer(server);
			}
			
			TerminalSessionData[] returnData = results.ToArray();
			return returnData;
		}
		
		public static TerminalSessionInfo GetSessionInfo(string ServerName, int SessionId)
		{
			IntPtr server = IntPtr.Zero;
			IntPtr buffer = IntPtr.Zero;
			int bytesReturned;
			TerminalSessionInfo data = new TerminalSessionInfo();
			bool _IsCurrentSessionId = false;
			bool _IsConsoleSession = false;
			bool _IsUserSession = false;
			int currentSessionID = 0;
			string _NTAccount = String.Empty;
			if (ServerName == "localhost" || ServerName == String.Empty)
			{
				ServerName = Environment.MachineName;
			}
			if (ProcessIdToSessionId(GetCurrentProcessId(), ref currentSessionID) == false)
			{
				currentSessionID = -1;
			}
			
			// Get all members of the local administrators group
			bool _IsLocalAdminCheckSuccess = false;
			List<string> localAdminGroupSidsList = new List<string>();
			try
			{
				DirectoryEntry localMachine = new DirectoryEntry("WinNT://" + ServerName + ",Computer");
				string localAdminGroupName = new SecurityIdentifier("S-1-5-32-544").Translate(typeof(NTAccount)).Value.Split('\\')[1];
				DirectoryEntry admGroup = localMachine.Children.Find(localAdminGroupName, "group");
				object members = admGroup.Invoke("members", null);
				string validSidPattern = @"^S-\d-\d+-(\d+-){1,14}\d+$";
				foreach (object groupMember in (IEnumerable)members)
				{
					DirectoryEntry member = new DirectoryEntry(groupMember);
					if (member.Name != String.Empty)
					{
						if (Regex.IsMatch(member.Name, validSidPattern))
						{
							localAdminGroupSidsList.Add(member.Name);
						}
						else
						{
							localAdminGroupSidsList.Add((new NTAccount(member.Name)).Translate(typeof(SecurityIdentifier)).Value);
						}
					}
				}
				_IsLocalAdminCheckSuccess = true;
			}
			catch { }
			
			try
			{
				server = OpenServer(ServerName);
				
				if (WTSQuerySessionInformation(server, SessionId, WTS_INFO_CLASS.ClientBuildNumber, out buffer, out bytesReturned) == false)
				{
					return data;
				}
				int lData = Marshal.ReadInt32(buffer);
				data.ClientBuildNumber = lData;
				
				if (WTSQuerySessionInformation(server, SessionId, WTS_INFO_CLASS.ClientDirectory, out buffer, out bytesReturned) == false)
				{
					return data;
				}
				string strData = Marshal.PtrToStringAnsi(buffer);
				data.ClientDirectory = strData;
				
				if (WTSQuerySessionInformation(server, SessionId, WTS_INFO_CLASS.ClientName, out buffer, out bytesReturned) == false)
				{
					return data;
				}
				strData = Marshal.PtrToStringAnsi(buffer);
				data.ClientName = strData;
				
				if (WTSQuerySessionInformation(server, SessionId, WTS_INFO_CLASS.ClientProtocolType, out buffer, out bytesReturned) == false)
				{
					return data;
				}
				Int16 intData = Marshal.ReadInt16(buffer);
				if (intData == 2)
				{
					strData = "RDP";
					data.IsRdpSession = true;
				}
				else
				{
					strData = "";
					data.IsRdpSession = false;
				}
				data.ClientProtocolType = strData;
				
				if (WTSQuerySessionInformation(server, SessionId, WTS_INFO_CLASS.ConnectState, out buffer, out bytesReturned) == false)
				{
					return data;
				}
				lData = Marshal.ReadInt32(buffer);
				data.ConnectState = ((WTS_CONNECTSTATE_CLASS) lData).ToString();
				
				if (WTSQuerySessionInformation(server, SessionId, WTS_INFO_CLASS.SessionId, out buffer, out bytesReturned) == false)
				{
					return data;
				}
				lData = Marshal.ReadInt32(buffer);
				data.SessionId = lData;
				
				if (WTSQuerySessionInformation(server, SessionId, WTS_INFO_CLASS.DomainName, out buffer, out bytesReturned) == false)
				{
					return data;
				}
				strData = Marshal.PtrToStringAnsi(buffer).ToUpper();
				data.DomainName = strData;
				if (strData != String.Empty)
				{
					_NTAccount = strData;
				}
				
				if (WTSQuerySessionInformation(server, SessionId, WTS_INFO_CLASS.UserName, out buffer, out bytesReturned) == false)
				{
					return data;
				}
				strData = Marshal.PtrToStringAnsi(buffer);
				data.UserName = strData;
				if (strData != String.Empty)
				{
					data.NTAccount = _NTAccount + "\\" + strData;
					string _Sid = (new NTAccount(_NTAccount + "\\" + strData)).Translate(typeof(SecurityIdentifier)).Value;
					data.SID = _Sid;
					if (_IsLocalAdminCheckSuccess == true)
					{
						foreach (string localAdminGroupSid in localAdminGroupSidsList)
						{
							if (localAdminGroupSid == _Sid)
							{
								data.IsLocalAdmin = true;
								break;
							}
							else
							{
								data.IsLocalAdmin = false;
							}
						}
					}
				}
				
				if (WTSQuerySessionInformation(server, SessionId, WTS_INFO_CLASS.SessionName, out buffer, out bytesReturned) == false)
				{
					return data;
				}
				strData = Marshal.PtrToStringAnsi(buffer);
				data.SessionName = strData;
				if (strData != "Services" && strData != "RDP-Tcp" && data.UserName != String.Empty)
				{
					_IsUserSession = true;
				}
				data.IsUserSession = _IsUserSession;
				if (strData == "Console")
				{
					_IsConsoleSession = true;
				}
				data.IsConsoleSession = _IsConsoleSession;
				
				WINSTATIONINFORMATIONW wsInfo = GetWinStationInformation(server, SessionId);
				DateTime? _loginTime = FileTimeToDateTime(wsInfo.LoginTime);
				DateTime? _lastInputTime = FileTimeToDateTime(wsInfo.LastInputTime);
				DateTime? _disconnectTime = FileTimeToDateTime(wsInfo.DisconnectTime);
				DateTime? _currentTime = FileTimeToDateTime(wsInfo.CurrentTime);
				TimeSpan? _idleTime = (_currentTime != null && _lastInputTime != null) ? _currentTime.Value - _lastInputTime.Value : TimeSpan.Zero;
				data.LogonTime = _loginTime;
				data.IdleTime = _idleTime;
				data.DisconnectTime = _disconnectTime;
				
				if (currentSessionID == SessionId)
				{
					_IsCurrentSessionId = true;
				}
				data.IsCurrentSession = _IsCurrentSessionId;
			}
			finally
			{
				WTSFreeMemory(buffer);
				buffer = IntPtr.Zero;
				CloseServer(server);
			}
			return data;
		}
		
		public static TerminalSessionInfo[] GetUserSessionInfo(string ServerName)
		{
			if (ServerName == "localhost" || ServerName == String.Empty)
			{
				ServerName = Environment.MachineName;
			}
			
			// Find and get detailed information for all user sessions
			// Also determine the active user session. If a console user exists, then that will be the active user session.
			// If no console user exists but users are logged in, such as on terminal servers, then select the first logged-in non-console user that is either 'Active' or 'Connected' as the active user.
			TerminalSessionData[] sessions = ListSessions(ServerName);
			TerminalSessionInfo sessionInfo = new TerminalSessionInfo();
			List<TerminalSessionInfo> userSessionsInfo = new List<TerminalSessionInfo>();
			string firstActiveUserNTAccount = String.Empty;
			bool IsActiveUserSessionSet = false;
			foreach (TerminalSessionData session in sessions)
			{
				if (session.IsUserSession == true)
				{
					sessionInfo = GetSessionInfo(ServerName, session.SessionId);
					if (sessionInfo.IsUserSession == true)
					{
						if ((firstActiveUserNTAccount == String.Empty) && (sessionInfo.ConnectState == "Active" || sessionInfo.ConnectState == "Connected"))
						{
							firstActiveUserNTAccount = sessionInfo.NTAccount;
						}
						
						if (sessionInfo.IsConsoleSession == true)
						{
							sessionInfo.IsActiveUserSession = true;
							IsActiveUserSessionSet = true;
						}
						else
						{
							sessionInfo.IsActiveUserSession = false;
						}
						
						userSessionsInfo.Add(sessionInfo);
					}
				}
			}
			
			TerminalSessionInfo[] userSessions = userSessionsInfo.ToArray();
			if (IsActiveUserSessionSet == false)
			{
				foreach (TerminalSessionInfo userSession in userSessions)
				{
					if (userSession.NTAccount == firstActiveUserNTAccount)
					{
						userSession.IsActiveUserSession = true;
						break;
					}
				}
			}
			
			return userSessions;
		}
	}
}
"@

Add-Type -ReferencedAssemblies $Assemblies -TypeDefinition $PSADT -Language CSharp

#endregion [CSharp Code]

#region [Environment Variables for the machine this is being installed on]

# ZeroConfig: Dot sourcing the zeroconfig.ps1
. "$PSScriptRoot\Data\zeroconfig.ps1"

# Variables: Datetime and Culture
[datetime]$currentDateTime = Get-Date
[string]$currentTime = Get-Date -Date $currentDateTime -UFormat '%T'
[string]$currentDate = Get-Date -Date $currentDateTime -UFormat '%d-%m-%Y'
[timespan]$currentTimeZoneBias = [timezone]::CurrentTimeZone.GetUtcOffset([datetime]::Now)
[Globalization.CultureInfo]$culture = Get-Culture
[string]$currentLanguage = $culture.TwoLetterISOLanguageName.ToUpper()
[Globalization.CultureInfo]$uiculture = Get-UICulture
[string]$currentUILanguage = $uiculture.TwoLetterISOLanguageName.ToUpper()

# Variables: Environment Variables
[psobject]$envHost = $Host
[psobject]$envShellFolders = Get-ItemProperty -Path 'HKLM:SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders' -ErrorAction 'SilentlyContinue'
[string]$envAllUsersProfile = $env:ALLUSERSPROFILE
[string]$envAppData = [Environment]::GetFolderPath('ApplicationData')
[string]$envArchitecture = $env:PROCESSOR_ARCHITECTURE
[string]$envCommonProgramFiles = [Environment]::GetFolderPath('CommonProgramFiles')
[string]$envCommonProgramFilesX86 = ${env:CommonProgramFiles(x86)}
[string]$envCommonDesktop = $envShellFolders | Select-Object -ExpandProperty 'Common Desktop' -ErrorAction 'SilentlyContinue'
[string]$envCommonDocuments = $envShellFolders | Select-Object -ExpandProperty 'Common Documents' -ErrorAction 'SilentlyContinue'
[string]$envCommonStartMenuPrograms = $envShellFolders | Select-Object -ExpandProperty 'Common Programs' -ErrorAction 'SilentlyContinue'
[string]$envCommonStartMenu = $envShellFolders | Select-Object -ExpandProperty 'Common Start Menu' -ErrorAction 'SilentlyContinue'
[string]$envCommonStartUp = $envShellFolders | Select-Object -ExpandProperty 'Common Startup' -ErrorAction 'SilentlyContinue'
[string]$envCommonTemplates = $envShellFolders | Select-Object -ExpandProperty 'Common Templates' -ErrorAction 'SilentlyContinue'
[string]$envComputerName = [Environment]::MachineName.ToUpper()
[string]$envComputerNameFQDN = ([Net.Dns]::GetHostEntry('localhost')).HostName
[string]$envHomeDrive = $env:HOMEDRIVE
[string]$envHomePath = $env:HOMEPATH
[string]$envHomeShare = $env:HOMESHARE
[string]$envLocalAppData = [Environment]::GetFolderPath('LocalApplicationData')
[string[]]$envLogicalDrives = [Environment]::GetLogicalDrives()
[string]$envProgramFiles = [Environment]::GetFolderPath('ProgramFiles')
[string]$envProgramFilesX86 = ${env:ProgramFiles(x86)}
[string]$envProgramData = [Environment]::GetFolderPath('CommonApplicationData')
[string]$envPublic = $env:PUBLIC
[string]$envSystemDrive = $env:SYSTEMDRIVE
[string]$envSystemRoot = $env:SYSTEMROOT
[string]$envTemp = [IO.Path]::GetTempPath()
[string]$envUserCookies = [Environment]::GetFolderPath('Cookies')
[string]$envUserDesktop = [Environment]::GetFolderPath('DesktopDirectory')
[string]$envUserFavorites = [Environment]::GetFolderPath('Favorites')
[string]$envUserInternetCache = [Environment]::GetFolderPath('InternetCache')
[string]$envUserInternetHistory = [Environment]::GetFolderPath('History')
[string]$envUserMyDocuments = [Environment]::GetFolderPath('MyDocuments')
[string]$envUserName = [Environment]::UserName
[string]$envUserPictures = [Environment]::GetFolderPath('MyPictures')
[string]$envUserProfile = $env:USERPROFILE
[string]$envUserSendTo = [Environment]::GetFolderPath('SendTo')
[string]$envUserStartMenu = [Environment]::GetFolderPath('StartMenu')
[string]$envUserStartMenuPrograms = [Environment]::GetFolderPath('Programs')
[string]$envUserStartUp = [Environment]::GetFolderPath('StartUp')
[string]$envUserTemplates = [Environment]::GetFolderPath('Templates')
[string]$envSystem32Directory = [Environment]::SystemDirectory
[string]$envWinDir = $env:WINDIR

#  Handle X86 environment variables so they are never empty
If (-not $envCommonProgramFilesX86) { [string]$envCommonProgramFilesX86 = $envCommonProgramFiles }
If (-not $envProgramFilesX86) { [string]$envProgramFilesX86 = $envProgramFiles }

## Variables: Domain Membership
[boolean]$IsMachinePartOfDomain = (Get-WmiObject -Class 'Win32_ComputerSystem' -ErrorAction 'SilentlyContinue').PartOfDomain
[string]$envMachineWorkgroup = ''
[string]$envMachineADDomain = ''
[string]$envLogonServer = ''
[string]$MachineDomainController = ''
If ($IsMachinePartOfDomain)
{
	[string]$envMachineADDomain = (Get-WmiObject -Class 'Win32_ComputerSystem' -ErrorAction 'SilentlyContinue').Domain | Where-Object { $_ } | ForEach-Object { $_.ToLower() }
	Try
	{
		[string]$envLogonServer = $env:LOGONSERVER | Where-Object { (($_) -and (-not $_.Contains('\\MicrosoftAccount'))) } | ForEach-Object { $_.TrimStart('\') } | ForEach-Object { ([Net.Dns]::GetHostEntry($_)).HostName }
		# If running in system context, fall back on the logonserver value stored in the registry
		If (-not $envLogonServer) { [string]$envLogonServer = Get-ItemProperty -LiteralPath 'HKLM:SOFTWARE\Microsoft\Windows\CurrentVersion\Group Policy\History' -ErrorAction 'SilentlyContinue' | Select-Object -ExpandProperty 'DCName' -ErrorAction 'SilentlyContinue' }
		[string]$MachineDomainController = [DirectoryServices.ActiveDirectory.Domain]::GetCurrentDomain().FindDomainController().Name
	}
	Catch { }
}
Else
{
	[string]$envMachineWorkgroup = (Get-WmiObject -Class 'Win32_ComputerSystem' -ErrorAction 'SilentlyContinue').Domain | Where-Object { $_ } | ForEach-Object { $_.ToUpper() }
}
[string]$envMachineDNSDomain = [Net.NetworkInformation.IPGlobalProperties]::GetIPGlobalProperties().DomainName | Where-Object { $_ } | ForEach-Object { $_.ToLower() }
[string]$envUserDNSDomain = $env:USERDNSDOMAIN | Where-Object { $_ } | ForEach-Object { $_.ToLower() }
Try
{
	[string]$envUserDomain = [Environment]::UserDomainName.ToUpper()
}
Catch { }

# Variables: Operating System
[psobject]$envOS = Get-WmiObject -Class 'Win32_OperatingSystem' -ErrorAction 'SilentlyContinue'
[string]$envOSName = $envOS.Caption.Trim()
[string]$envOSServicePack = $envOS.CSDVersion
[version]$envOSVersion = $envOS.Version
[string]$envOSVersionMajor = $envOSVersion.Major
[string]$envOSVersionMinor = $envOSVersion.Minor
[string]$envOSVersionBuild = $envOSVersion.Build
If ($envOSVersionMajor -eq 10) { $envOSVersionRevision = (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -Name 'UBR' -ErrorAction SilentlyContinue).UBR }
Else { [string]$envOSVersionRevision = ,((Get-ItemProperty -Path 'HKLM:SOFTWARE\Microsoft\Windows NT\CurrentVersion' -Name 'BuildLabEx' -ErrorAction 'SilentlyContinue').BuildLabEx -split '\.') | ForEach-Object { $_[1] } }
If ($envOSVersionRevision -notmatch '^[\d\.]+$') { $envOSVersionRevision = '' }
If ($envOSVersionRevision) { [string]$envOSVersion = "$($envOSVersion.ToString()).$envOSVersionRevision" }
Else { "$($envOSVersion.ToString())" }

#  Get the operating system type
[int32]$envOSProductType = $envOS.ProductType
[boolean]$IsServerOS = [boolean]($envOSProductType -eq 3)
[boolean]$IsDomainControllerOS = [boolean]($envOSProductType -eq 2)
[boolean]$IsWorkStationOS = [boolean]($envOSProductType -eq 1)
Switch ($envOSProductType)
{
	3 { [string]$envOSProductTypeName = 'Server' }
	2 { [string]$envOSProductTypeName = 'Domain Controller' }
	1 { [string]$envOSProductTypeName = 'Workstation' }
	Default { [string]$envOSProductTypeName = 'Unknown' }
}

## Variables: Current Process Architecture
[boolean]$Is64BitProcess = [boolean]([IntPtr]::Size -eq 8)
If ($Is64BitProcess) { [string]$psArchitecture = 'x64' }
Else { [string]$psArchitecture = 'x86' }

#  Get the OS Architecture
[boolean]$Is64Bit = [boolean]((Get-WmiObject -Class 'Win32_Processor' -ErrorAction 'SilentlyContinue' | Where-Object { $_.DeviceID -eq 'CPU0' } | Select-Object -ExpandProperty 'AddressWidth') -eq 64)
If ($Is64Bit) { [string]$envOSArchitecture = '64-bit' }
Else { [string]$envOSArchitecture = '32-bit' }

## Variables: Permissions/Accounts
[Security.Principal.WindowsIdentity]$CurrentProcessToken = [Security.Principal.WindowsIdentity]::GetCurrent()
[Security.Principal.SecurityIdentifier]$CurrentProcessSID = $CurrentProcessToken.User
[string]$ProcessNTAccount = $CurrentProcessToken.Name
[string]$ProcessNTAccountSID = $CurrentProcessSID.Value
[boolean]$IsAdmin = [boolean]($CurrentProcessToken.Groups -contains [Security.Principal.SecurityIdentifier]'S-1-5-32-544')
[boolean]$IsLocalSystemAccount = $CurrentProcessSID.IsWellKnown([Security.Principal.WellKnownSidType]'LocalSystemSid')
[boolean]$IsLocalServiceAccount = $CurrentProcessSID.IsWellKnown([Security.Principal.WellKnownSidType]'LocalServiceSid')
[boolean]$IsNetworkServiceAccount = $CurrentProcessSID.IsWellKnown([Security.Principal.WellKnownSidType]'NetworkServiceSid')
[boolean]$IsServiceAccount = [boolean]($CurrentProcessToken.Groups -contains [Security.Principal.SecurityIdentifier]'S-1-5-6')
[boolean]$IsProcessUserInteractive = [Environment]::UserInteractive
[string]$LocalSystemNTAccount = (New-Object -TypeName 'System.Security.Principal.SecurityIdentifier' -ArgumentList ([Security.Principal.WellKnownSidType]::'LocalSystemSid', $null)).Translate([Security.Principal.NTAccount]).Value

#  Check if script is running in session zero
If ($IsLocalSystemAccount -or $IsLocalServiceAccount -or $IsNetworkServiceAccount -or $IsServiceAccount) { $SessionZero = $true }
Else { $SessionZero = $false }

## Variables: Registry Keys
#  Registry keys for native and WOW64 applications
[string[]]$regKeyApplications = 'HKLM:SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall', 'HKLM:SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall'
If ($is64Bit)
{
	[string]$regKeyLotusNotes = 'HKLM:SOFTWARE\Wow6432Node\Lotus\Notes'
}
Else
{
	[string]$regKeyLotusNotes = 'HKLM:SOFTWARE\Lotus\Notes'
}
[string]$regKeyAppExecution = 'HKLM:SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options'

## COM Objects: Initialize
[__comobject]$Shell = New-Object -ComObject 'WScript.Shell' -ErrorAction 'SilentlyContinue'
[__comobject]$ShellApp = New-Object -ComObject 'Shell.Application' -ErrorAction 'SilentlyContinue'

## Variables: Reset/Remove Variables
[boolean]$msiRebootDetected = $false
[boolean]$BlockExecution = $false
[boolean]$installationStarted = $false
[boolean]$runningTaskSequence = $false
If (Test-Path -LiteralPath 'variable:welcomeTimer') { Remove-Variable -Name 'welcomeTimer' -Scope 'Script' }

#  Reset the deferral history
If (Test-Path -LiteralPath 'variable:deferHistory') { Remove-Variable -Name 'deferHistory' }
If (Test-Path -LiteralPath 'variable:deferTimes') { Remove-Variable -Name 'deferTimes' }
If (Test-Path -LiteralPath 'variable:deferDays') { Remove-Variable -Name 'deferDays' }


## Variables: Hardware
[int32]$envSystemRAM = Get-WMIObject -Class Win32_PhysicalMemory -ComputerName $env:COMPUTERNAME -ErrorAction 'SilentlyContinue' | Measure-Object -Property Capacity -Sum -ErrorAction SilentlyContinue | ForEach-Object { [Math]::Round(($_.sum / 1GB), 2) }

## Variables: PowerShell And CLR (.NET) Versions
[hashtable]$envPSVersionTable = $PSVersionTable

#  PowerShell Version
[version]$envPSVersion = $envPSVersionTable.PSVersion
[string]$envPSVersionMajor = $envPSVersion.Major
[string]$envPSVersionMinor = $envPSVersion.Minor
[string]$envPSVersionBuild = $envPSVersion.Build
[string]$envPSVersionRevision = $envPSVersion.Revision
[string]$envPSVersion = $envPSVersion.ToString()

#  CLR (.NET) Version used by PowerShell
[version]$envCLRVersion = $envPSVersionTable.CLRVersion
[string]$envCLRVersionMajor = $envCLRVersion.Major
[string]$envCLRVersionMinor = $envCLRVersion.Minor
[string]$envCLRVersionBuild = $envCLRVersion.Build
[string]$envCLRVersionRevision = $envCLRVersion.Revision
[string]$envCLRVersion = $envCLRVersion.ToString()

## Variables: Executables
[string]$exeWusa = 'wusa.exe' # Installs Standalone Windows Updates
[string]$exeMsiexec = 'msiexec.exe' # Installs MSI Installers
[string]$exeSchTasks = "$envWinDir\System32\schtasks.exe" # Manages Scheduled Tasks

#endregion [Environment Variables for the machine this is being installed on]

#region [Other Variables]

## Variables: Script Name and Script Paths
[string]$scriptPath = $PSScriptRoot
[string]$scriptName = $PSCommandPath
[string]$scriptFileName = Split-Path -Path $scriptPath -Leaf
[string]$scriptRoot = Split-Path -Path $scriptPath -Parent
[string]$invokingScript = (Get-Variable -Name 'MyInvocation').Value.ScriptName
$global:PromptedInstall = 0
#  Get the invoking script directory
If ($invokingScript)
{
	#  If this script was invoked by another script
	[string]$scriptParentPath = Split-Path -Path $invokingScript -Parent
}
Else
{
	#  If this script was not invoked by another script, fall back to the directory one level above this script
	[string]$scriptParentPath = (Get-Item -LiteralPath $scriptRoot).Parent.FullName
}

# Script directories
[string]$dirFiles = Join-Path -Path $scriptPath -ChildPath 'Data'
[string]$dirSupportFiles = Join-Path -Path $scriptPath -ChildPath 'SupportFiles'
#[string]$dirAppDeployTemp = Join-Path -Path $configToolkitTempPath -ChildPath $appDeployToolkitName
[string]$configToolkitCachePath = $env:TEMP

#  Get Toolkit Options
[boolean]$configToolkitRequireAdmin = $true
[string]$configToolkitTempPath = "$env:TEMP\InstallLogs"
[string]$configToolkitLogDir = "${env:CommonProgramFiles(x86)}\InstallLogs"
[boolean]$configToolkitCompressLogs = $false # if set to to true default folder logging folder goes to TempPath
[string]$configToolkitLogStyle = 'CMTrace'
[double]$configToolkitLogMaxSize = 10
[boolean]$configToolkitLogWriteToHost = $false
[boolean]$configToolkitLogDebugMessage = $false
[boolean]$configToolkitUseRobocopy = $true

#  Get MSI Options
[string]$configMSILoggingOptions = "/L*v"
[string]$configMSIInstallParams = "REBOOT=ReallySuppress /QB!"
[string]$configMSISilentParams = "REBOOT=ReallySuppress /QN"
[string]$configMSIUninstallParams = "REBOOT=ReallySuppress /QN"
[string]$configMSILogDir = "${env:CommonProgramFiles(x86)}\InstallLogs"
[string]$logTempFolder = "$env:TEMP\InstallLogs"
[int32]$configMSIMutexWaitTime = 2
[bool]$deployModeSilent = $true

## Variables: RegEx Patterns
[string]$MSIProductCodeRegExPattern = '^(\{{0,1}([0-9a-fA-F]){8}-([0-9a-fA-F]){4}-([0-9a-fA-F]){4}-([0-9a-fA-F]){4}-([0-9a-fA-F]){12}\}{0,1})$'

## Set illegal file char variable
[char[]]$invalidFileNameChars = [IO.Path]::GetInvalidFileNameChars()

## PSADT Mutex Variables
$mutexName = "Global\PSADTAppLock"
$mtx = New-Object System.Threading.Mutex($false, $mutexName)
$waitSeconds = 30
$maxDuration = (Get-Date).AddMinutes(5)

#endregion [Other Variables]

#region [TESTING FUNCTIONS]

function Delete-Service([string]$ServiceName)
{
	
		<#
		.SYNOPSIS
			This function stops and deletes a Windows service. This function does not terminate a windows process. Do not use it for that as it will fail.

		.OUTPUTS
			$true = Service deleted
			$false = Service not deleted

		This service will return $true if:

			The service no longer exists in the services database
			The service was STOPPED and changed to DISABLED by the function.

		.NOTES
			There are conditions in which a service will be marked for deletion but will still be listed as a service. The service properties will be set to
			STOPPED and DISABLED. This service will be deleted when the PC is rebooted.

		.PARANETER
			-ServiceName

		.EXAMPLE

			Delete-Service -ServiceName NACAgent
		
		This function accepts the literal service name  not the DisplayNamee (NACAgent in this example) only.

		#>
	
	[bool]$Return = $False
	$Service = Get-WmiObject -Class Win32_Service -Filter "Name='$ServiceName'"
	try
	{
		if ($Service)
		{
			$Service.StopService() | Out-Null
			$Service.Delete() | Out-Null
			if (!($ServiceName))
			{
				$Return = $True
			}
		}
		else
		{
			$Return = $True
		}
		if ($Service.State -eq "Stopped" -and $Service.Startmode -eq "Disabled")
		{
			$Return = $True
		}
	}
	
	catch [System.Exception] {
		$Return = $False
	}
	catch
	{
		$Return = $False
	}
	return $Return
}

#endregion [TESTING FUNCTIONS]

#region [FUNCTIONS]

#region Function ConvertStringTo-FRBProcess
function ConvertStringTo-FRBProcess
{
	<#
	.SYNOPSIS
		Converts string of open process to use in other function
		Returns FRB Process Objects
	.EXAMPLE
			$FRBOpenProcessesToCheck = ConvertStringTo-FRBProcess -strOpenProcess $OPENProcessStr
	#>
	
	param (
		[Parameter(Mandatory = $true)]
		[string]$strOpenProcess
	)
	$objStrings = $strOpenProcess -Split ";"
	foreach ($objs in $objStrings)
	{
		Try
		{
			$objArray = $objs -Split ","
			$ProcessNameInitial = ($objArray[1].split("."))
			If ($ProcessNameInitial.Count -gt 2) #Accounts for executable name containing more than one period 
			{
				$revisedName = ''
				$i = 1
				foreach ($item in $ProcessNameInitial)
				{
					If ($i -ne $ProcessNameInitial.Count)
					{
						$revisedName = $revisedName + "$item"
						If ($i -ne ($ProcessNameInitial.Count - 1))
						{
							$revisedName = $revisedName + "."
						}
					}
					$i++
				}
				
				[pscustomobject] @{
					FriendlyDescription = $objArray[0]
					Processname		    = $revisedName
					DoPrompt		    = $objArray[2].toBoolean((Get-Culture))
				}
			}
			Else
			{
				#Accounts for for standard executable name with a single period
				[pscustomobject] @{
					FriendlyDescription = $objArray[0]
					Processname		    = ($objArray[1].split("."))[0]
					DoPrompt		    = $objArray[2].toBoolean((Get-Culture))
				}
			}
		}
		Catch [System.Exception]{ } #This catch is capture null values from ln 645   
	}
}
#endregion

#region Function Format-FRBProcesses
function Format-FRBProcesses
{
	param (
		[Parameter(Mandatory = $true)]
		[string]$appStopRequiredProcesses
	)
	$labeltxt = ''
	$FRBOpenProcessesToCheck = ConvertStringTo-FRBProcess -strOpenProcess $appStopRequiredProcesses
	$OpenProcessesPrompt = $FRBOpenProcessesToCheck | Get-FRBOpenProcess -DoPrompt
	if ($OpenProcessesPrompt)
	{
		$CloseList = ($OpenProcessesPrompt | select-Object FriendlyDescription).FriendlyDescription
		foreach ($process in $CloseList)
		{
			If ($labeltxt -eq '')
			{
				$labeltxt = $process
			}
			Else
			{
				$labeltxt = "$labeltxt, " + $process
			}
		}
	}
	return $labeltxt
}
#endregion

#region Function Get-FRBOpenProcess
function Get-FRBOpenProcess
{
	<#
	.SYNOPSIS
		Retrieves open processes from an array
	.EXAMPLE
		Get-FRBOpenProcess -FRBProcess $FRBProcess
	#>
	
	param (
		[Parameter(Mandatory = $true,
				   ValueFromPipeline = $true,
				   Position = 0,
				   HelpMessage = "An array of FRBprocess Objects to kill.")]
		$FRBProcess,
		[switch]$doPrompt
	)
	process
	{
		If ($doPrompt)
		{
			if ($FRBProcess.doPrompt)
			{
				if (Get-Process -Name $FRBProcess.processname -ErrorAction SilentlyContinue)
				{
					$FRBProcess
				}
			}
		}
		else
		{
			if (Get-Process -Name $FRBProcess.processname -ErrorAction SilentlyContinue)
			{
				$FRBProcess
			}
		}
	}
}
#endregion

#region Function Kill-FRBProcesses
Function Kill-FRBProcesses
{
		<#
		.SYNOPSIS
			Kills passed processes

		.EXAMPLE
			ConvertStringTo-FRBProcess -strOpenProcess $PKGR_STOPREQUIREDPROCESSES | Kill-FRBProcesses
		#>
	
	param (
		[Parameter(Mandatory = $true,
				   ValueFromPipeline = $true,
				   HelpMessage = "An array of process names to kill.")
		]
		$FRBProcessToKill
	)
	process
	{
		$FRBProcessToKill | Stop-Process -ErrorAction 'SilentlyContinue' -Force
	}
}
#endregion

#region Function Unblock-AppExecution
Function Unblock-AppExecution
{
<#
.SYNOPSIS
	Unblocks the execution of applications performed by the Block-AppExecution function
.DESCRIPTION
	This function is called by the Exit-Script function or when the script itself is called with the parameters -CleanupBlockedApps
.DEPENDENCIES
	
.EXAMPLE
	Unblock-AppExecution
.NOTES
	This is an internal script function and should typically not be called directly.
	It is used when the -BlockExecution parameter is specified with the Show-InstallationWelcome function to undo the actions performed by Block-AppExecution.
.LINK
	http://psappdeploytoolkit.com
#>
	[CmdletBinding()]
	Param (
	)
	
	Begin
	{
		## Get the name of this function and write header
		[string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
		Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -CmdletBoundParameters $PSBoundParameters -Header
	}
	Process
	{
		## Bypass if in NonInteractive mode
		If ($deployModeNonInteractive)
		{
			Write-Log -Message "Bypassing Function [${CmdletName}] [Mode: $deployMode]." -Source ${CmdletName}
			Return
		}
		
		## Remove Debugger values to unblock processes
		[psobject[]]$unblockProcesses = $null
		[psobject[]]$unblockProcesses += (Get-ChildItem -LiteralPath $regKeyAppExecution -Recurse -ErrorAction 'SilentlyContinue' | ForEach-Object { Get-ItemProperty -LiteralPath $_.PSPath -ErrorAction 'SilentlyContinue' })
		ForEach ($unblockProcess in ($unblockProcesses | Where-Object { $_.Debugger -like '*AppDeployToolkit_BlockAppExecutionMessage*' }))
		{
			Write-Log -Message "Remove the Image File Execution Options registry key to unblock execution of [$($unblockProcess.PSChildName)]." -Source ${CmdletName}
			$unblockProcess | Remove-ItemProperty -Name 'Debugger' -ErrorAction 'SilentlyContinue'
		}
		
		## If block execution variable is $true, set it to $false
		If ($BlockExecution)
		{
			#  Make this variable globally available so we can check whether we need to call Unblock-AppExecution
			Set-Variable -Name 'BlockExecution' -Value $false -Scope 'Script'
		}
		
		## Remove the scheduled task if it exists
		[string]$schTaskBlockedAppsName = $installName + '_BlockedApps'
		Try
		{
			If (Get-ScheduledTask -ContinueOnError $true | Select-Object -Property 'TaskName' | Where-Object { $_.TaskName -eq "\$schTaskBlockedAppsName" })
			{
				Write-Log -Message "Delete Scheduled Task [$schTaskBlockedAppsName]." -Source ${CmdletName}
				Execute-Process -Path $exeSchTasks -Parameters "/Delete /TN $schTaskBlockedAppsName /F"
			}
		}
		Catch
		{
			Write-Log -Message "Error retrieving/deleting Scheduled Task.`n$(Resolve-Error)" -Severity 3 -Source ${CmdletName}
		}
	}
	End
	{
		Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -Footer
	}
}
#endregion

#region Function Invoke-RegisterOrUnregisterDLL
Function Invoke-RegisterOrUnregisterDLL
{
<#
.SYNOPSIS
	Register or unregister a DLL file.
.DESCRIPTION
	Register or unregister a DLL file using regsvr32.exe. Function can be invoked using alias: 'Register-DLL' or 'Unregister-DLL'.
.PARAMETER FilePath
	Path to the DLL file.
.PARAMETER DLLAction
	Specify whether to register or unregister the DLL. Optional if function is invoked using 'Register-DLL' or 'Unregister-DLL' alias.
.PARAMETER ContinueOnError
	Continue if an error is encountered. Default is: $true.
.EXAMPLE
	Register-DLL -FilePath "C:\Test\DcTLSFileToDMSComp.dll"
	Register DLL file using the "Register-DLL" alias for this function
.EXAMPLE
	UnRegister-DLL -FilePath "C:\Test\DcTLSFileToDMSComp.dll"
	Unregister DLL file using the "Unregister-DLL" alias for this function
.EXAMPLE
	Invoke-RegisterOrUnregisterDLL -FilePath "C:\Test\DcTLSFileToDMSComp.dll" -DLLAction 'Register'
	Register DLL file using the actual name of this function
.NOTES
.LINK
	http://psappdeploytoolkit.com
#>
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $true)]
		[ValidateNotNullorEmpty()]
		[string]$FilePath,
		[Parameter(Mandatory = $false)]
		[ValidateSet('Register', 'Unregister')]
		[string]$DLLAction,
		[Parameter(Mandatory = $false)]
		[ValidateNotNullorEmpty()]
		[boolean]$ContinueOnError = $true
	)
	
	Begin
	{
		## Get the name of this function and write header
		[string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
		Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -CmdletBoundParameters $PSBoundParameters -Header
		
		## Get name used to invoke this function in case the 'Register-DLL' or 'Unregister-DLL' alias was used and set the correct DLL action
		[string]${InvokedCmdletName} = $MyInvocation.InvocationName
		#  Set the correct register/unregister action based on the alias used to invoke this function
		If (${InvokedCmdletName} -ne ${CmdletName})
		{
			Switch (${InvokedCmdletName})
			{
				'Register-DLL' { [string]$DLLAction = 'Register' }
				'Unregister-DLL' { [string]$DLLAction = 'Unregister' }
			}
		}
		#  Set the correct DLL register/unregister action parameters
		If (-not $DLLAction) { Throw 'Parameter validation failed. Please specify the [-DLLAction] parameter to determine whether to register or unregister the DLL.' }
		[string]$DLLAction = ((Get-Culture).TextInfo).ToTitleCase($DLLAction.ToLower())
		Switch ($DLLAction)
		{
			'Register' { [string]$DLLActionParameters = "/s `"$FilePath`"" }
			'Unregister' { [string]$DLLActionParameters = "/s /u `"$FilePath`"" }
		}
	}
	Process
	{
		Try
		{
			Write-Log -Message "$DLLAction DLL file [$filePath]." -Source ${CmdletName}
			If (-not (Test-Path -LiteralPath $FilePath -PathType 'Leaf')) { Throw "File [$filePath] could not be found." }
			
			[string]$DLLFileBitness = Get-PEFileArchitecture -FilePath $filePath -ContinueOnError $false -ErrorAction 'Stop'
			If (($DLLFileBitness -ne '64BIT') -and ($DLLFileBitness -ne '32BIT'))
			{
				Throw "File [$filePath] has a detected file architecture of [$DLLFileBitness]. Only 32-bit or 64-bit DLL files can be $($DLLAction.ToLower() + 'ed')."
			}
			
			If ($Is64Bit)
			{
				If ($DLLFileBitness -eq '64BIT')
				{
					If ($Is64BitProcess)
					{
						[string]$RegSvr32Path = "$envWinDir\system32\regsvr32.exe"
					}
					Else
					{
						[string]$RegSvr32Path = "$envWinDir\sysnative\regsvr32.exe"
					}
				}
				ElseIf ($DLLFileBitness -eq '32BIT')
				{
					[string]$RegSvr32Path = "$envWinDir\SysWOW64\regsvr32.exe"
				}
			}
			Else
			{
				If ($DLLFileBitness -eq '64BIT')
				{
					Throw "File [$filePath] cannot be $($DLLAction.ToLower()) because it is a 64-bit file on a 32-bit operating system."
				}
				ElseIf ($DLLFileBitness -eq '32BIT')
				{
					[string]$RegSvr32Path = "$envWinDir\system32\regsvr32.exe"
				}
			}
			
			[psobject]$ExecuteResult = Execute-Process -Path $RegSvr32Path -Parameters $DLLActionParameters -WindowStyle 'Hidden' -PassThru
			
			If ($ExecuteResult.ExitCode -ne 0)
			{
				If ($ExecuteResult.ExitCode -eq 60002)
				{
					Throw "Execute-Process function failed with exit code [$($ExecuteResult.ExitCode)]."
				}
				Else
				{
					Throw "regsvr32.exe failed with exit code [$($ExecuteResult.ExitCode)]."
				}
			}
		}
		Catch
		{
			Write-Log -Message "Failed to $($DLLAction.ToLower()) DLL file. `n$(Resolve-Error)" -Severity 3 -Source ${CmdletName}
			If (-not $ContinueOnError)
			{
				Throw "Failed to $($DLLAction.ToLower()) DLL file: $($_.Exception.Message)"
			}
		}
	}
	End
	{
		Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -Footer
	}
}
Set-Alias -Name 'Register-DLL' -Value 'Invoke-RegisterOrUnregisterDLL' -Scope 'Script' -Force -ErrorAction 'SilentlyContinue'
Set-Alias -Name 'Unregister-DLL' -Value 'Invoke-RegisterOrUnregisterDLL' -Scope 'Script' -Force -ErrorAction 'SilentlyContinue'
#endregion

#region Function Get-WindowTitle
Function Get-WindowTitle
{
<#
.SYNOPSIS
	Search for an open window title and return details about the window.
.DESCRIPTION
	Search for a window title. If window title searched for returns more than one result, then details for each window will be displayed.
	Returns the following properties for each window: WindowTitle, WindowHandle, ParentProcess, ParentProcessMainWindowHandle, ParentProcessId.
	Function does not work in SYSTEM context unless launched with "psexec.exe -s -i" to run it as an interactive process under the SYSTEM account.
.PARAMETER WindowTitle
	The title of the application window to search for using regex matching.
.PARAMETER GetAllWindowTitles
	Get titles for all open windows on the system.
.PARAMETER DisableFunctionLogging
	Disables logging messages to the script log file.
.EXAMPLE
	Get-WindowTitle -WindowTitle 'Microsoft Word'
	Gets details for each window that has the words "Microsoft Word" in the title.
.EXAMPLE
	Get-WindowTitle -GetAllWindowTitles
	Gets details for all windows with a title.
.EXAMPLE
	Get-WindowTitle -GetAllWindowTitles | Where-Object { $_.ParentProcess -eq 'WINWORD' }
	Get details for all windows belonging to Microsoft Word process with name "WINWORD".
.NOTES
.LINK
	http://psappdeploytoolkit.com
#>
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $true, ParameterSetName = 'SearchWinTitle')]
		[AllowEmptyString()]
		[string]$WindowTitle,
		[Parameter(Mandatory = $true, ParameterSetName = 'GetAllWinTitles')]
		[ValidateNotNullorEmpty()]
		[switch]$GetAllWindowTitles = $false,
		[Parameter(Mandatory = $false)]
		[ValidateNotNullorEmpty()]
		[switch]$DisableFunctionLogging = $false
	)
	
	Begin
	{
		## Get the name of this function and write header
		[string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
		Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -CmdletBoundParameters $PSBoundParameters -Header
	}
	Process
	{
		Try
		{
			If ($PSCmdlet.ParameterSetName -eq 'SearchWinTitle')
			{
				If (-not $DisableFunctionLogging) { Write-Log -Message "Find open window title(s) [$WindowTitle] using regex matching." -Source ${CmdletName} }
			}
			ElseIf ($PSCmdlet.ParameterSetName -eq 'GetAllWinTitles')
			{
				If (-not $DisableFunctionLogging) { Write-Log -Message 'Find all open window title(s).' -Source ${CmdletName} }
			}
			
			## Get all window handles for visible windows
			[IntPtr[]]$VisibleWindowHandles = [PSADT.UiAutomation]::EnumWindows() | Where-Object { [PSADT.UiAutomation]::IsWindowVisible($_) }
			
			## Discover details about each visible window that was discovered
			ForEach ($VisibleWindowHandle in $VisibleWindowHandles)
			{
				If (-not $VisibleWindowHandle) { Continue }
				## Get the window title
				[string]$VisibleWindowTitle = [PSADT.UiAutomation]::GetWindowText($VisibleWindowHandle)
				If ($VisibleWindowTitle)
				{
					## Get the process that spawned the window
					[Diagnostics.Process]$Process = Get-Process -ErrorAction 'Stop' | Where-Object { $_.Id -eq [PSADT.UiAutomation]::GetWindowThreadProcessId($VisibleWindowHandle) }
					If ($Process)
					{
						## Build custom object with details about the window and the process
						[psobject]$VisibleWindow = New-Object -TypeName 'PSObject' -Property @{
							WindowTitle   = $VisibleWindowTitle
							WindowHandle  = $VisibleWindowHandle
							ParentProcess = $Process.Name
							ParentProcessMainWindowHandle = $Process.MainWindowHandle
							ParentProcessId = $Process.Id
						}
						
						## Only save/return the window and process details which match the search criteria
						If ($PSCmdlet.ParameterSetName -eq 'SearchWinTitle')
						{
							$MatchResult = $VisibleWindow.WindowTitle -match $WindowTitle
							If ($MatchResult)
							{
								[psobject[]]$VisibleWindows += $VisibleWindow
							}
						}
						ElseIf ($PSCmdlet.ParameterSetName -eq 'GetAllWinTitles')
						{
							[psobject[]]$VisibleWindows += $VisibleWindow
						}
					}
				}
			}
		}
		Catch
		{
			If (-not $DisableFunctionLogging) { Write-Log -Message "Failed to get requested window title(s). `n$(Resolve-Error)" -Severity 3 -Source ${CmdletName} }
		}
	}
	End
	{
		Write-Output -InputObject $VisibleWindows
		
		If ($DisableFunctionLogging) { . $RevertScriptLogging }
		Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -Footer
	}
}
#endregion

#region Function Send-Keys
Function Send-Keys
{
<#
.SYNOPSIS
	Send a sequence of keys to one or more application windows.
.DESCRIPTION
	Send a sequence of keys to one or more application window. If window title searched for returns more than one window, then all of them will receive the sent keys.
	Function does not work in SYSTEM context unless launched with "psexec.exe -s -i" to run it as an interactive process under the SYSTEM account.
.PARAMETER WindowTitle
	The title of the application window to search for using regex matching.
.PARAMETER GetAllWindowTitles
	Get titles for all open windows on the system.
.PARAMETER WindowHandle
	Send keys to a specific window where the Window Handle is already known.
.PARAMETER Keys
	The sequence of keys to send. Info on Key input at: http://msdn.microsoft.com/en-us/library/System.Windows.Forms.SendKeys(v=vs.100).aspx
.PARAMETER WaitSeconds
	An optional number of seconds to wait after the sending of the keys.
.EXAMPLE
	Send-Keys -WindowTitle 'foobar - Notepad' -Key 'Hello world'
	Send the sequence of keys "Hello world" to the application titled "foobar - Notepad".
.EXAMPLE
	Send-Keys -WindowTitle 'foobar - Notepad' -Key 'Hello world' -WaitSeconds 5
	Send the sequence of keys "Hello world" to the application titled "foobar - Notepad" and wait 5 seconds.
.EXAMPLE
	Send-Keys -WindowHandle ([IntPtr]17368294) -Key 'Hello world'
	Send the sequence of keys "Hello world" to the application with a Window Handle of '17368294'.
.NOTES
.LINK
	http://msdn.microsoft.com/en-us/library/System.Windows.Forms.SendKeys(v=vs.100).aspx
	http://psappdeploytoolkit.com
#>
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $false, Position = 0)]
		[AllowEmptyString()]
		[ValidateNotNull()]
		[string]$WindowTitle,
		[Parameter(Mandatory = $false, Position = 1)]
		[ValidateNotNullorEmpty()]
		[switch]$GetAllWindowTitles = $false,
		[Parameter(Mandatory = $false, Position = 2)]
		[ValidateNotNullorEmpty()]
		[IntPtr]$WindowHandle,
		[Parameter(Mandatory = $false, Position = 3)]
		[ValidateNotNullorEmpty()]
		[string]$Keys,
		[Parameter(Mandatory = $false, Position = 4)]
		[ValidateNotNullorEmpty()]
		[int32]$WaitSeconds
	)
	
	Begin
	{
		## Get the name of this function and write header
		[string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
		Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -CmdletBoundParameters $PSBoundParameters -Header
		
		## Load assembly containing class System.Windows.Forms.SendKeys
		Add-Type -AssemblyName 'System.Windows.Forms' -ErrorAction 'Stop'
		
		[scriptblock]$SendKeys = {
			Param (
				[Parameter(Mandatory = $true)]
				[ValidateNotNullorEmpty()]
				[IntPtr]$WindowHandle
			)
			Try
			{
				## Bring the window to the foreground
				[boolean]$IsBringWindowToFrontSuccess = [PSADT.UiAutomation]::BringWindowToFront($WindowHandle)
				If (-not $IsBringWindowToFrontSuccess) { Throw 'Failed to bring window to foreground.' }
				
				## Send the Key sequence
				If ($Keys)
				{
					[boolean]$IsWindowModal = If ([PSADT.UiAutomation]::IsWindowEnabled($WindowHandle)) { $false }
					Else { $true }
					If ($IsWindowModal) { Throw 'Unable to send keys to window because it may be disabled due to a modal dialog being shown.' }
					[Windows.Forms.SendKeys]::SendWait($Keys)
					Write-Log -Message "Sent key(s) [$Keys] to window title [$($Window.WindowTitle)] with window handle [$WindowHandle]." -Source ${CmdletName}
					
					If ($WaitSeconds)
					{
						Write-Log -Message "Sleeping for [$WaitSeconds] seconds." -Source ${CmdletName}
						Start-Sleep -Seconds $WaitSeconds
					}
				}
			}
			Catch
			{
				Write-Log -Message "Failed to send keys to window title [$($Window.WindowTitle)] with window handle [$WindowHandle]. `n$(Resolve-Error)" -Severity 3 -Source ${CmdletName}
			}
		}
	}
	Process
	{
		Try
		{
			If ($WindowHandle)
			{
				[psobject]$Window = Get-WindowTitle -GetAllWindowTitles | Where-Object { $_.WindowHandle -eq $WindowHandle }
				If (-not $Window)
				{
					Write-Log -Message "No windows with Window Handle [$WindowHandle] were discovered." -Severity 2 -Source ${CmdletName}
					Return
				}
				& $SendKeys -WindowHandle $Window.WindowHandle
			}
			Else
			{
				[hashtable]$GetWindowTitleSplat = @{ }
				If ($GetAllWindowTitles) { $GetWindowTitleSplat.Add('GetAllWindowTitles', $GetAllWindowTitles) }
				Else { $GetWindowTitleSplat.Add('WindowTitle', $WindowTitle) }
				[psobject[]]$AllWindows = Get-WindowTitle @GetWindowTitleSplat
				If (-not $AllWindows)
				{
					Write-Log -Message 'No windows with the specified details were discovered.' -Severity 2 -Source ${CmdletName}
					Return
				}
				
				ForEach ($Window in $AllWindows)
				{
					& $SendKeys -WindowHandle $Window.WindowHandle
				}
			}
		}
		Catch
		{
			Write-Log -Message "Failed to send keys to specified window. `n$(Resolve-Error)" -Severity 3 -Source ${CmdletName}
		}
	}
	End
	{
		Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -Footer
	}
}
#endregion

#region Function Test-NetworkConnection
Function Test-NetworkConnection
{
<#
.SYNOPSIS
	Tests for an active local network connection, excluding wireless and virtual network adapters.
.DESCRIPTION
	Tests for an active local network connection, excluding wireless and virtual network adapters, by querying the Win32_NetworkAdapter WMI class.
.DEPENDENCIES
	
.EXAMPLE
	Test-NetworkConnection
.NOTES
.LINK
	http://psappdeploytoolkit.com
#>
	[CmdletBinding()]
	Param (
	)
	
	Begin
	{
		## Get the name of this function and write header
		[string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
		Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -CmdletBoundParameters $PSBoundParameters -Header
	}
	Process
	{
		Write-Log -Message 'Check if system is using a wired network connection...' -Source ${CmdletName}
		
		[psobject[]]$networkConnected = Get-WmiObject -Class 'Win32_NetworkAdapter' | Where-Object { ($_.NetConnectionStatus -eq 2) -and ($_.NetConnectionID -match 'Local' -or $_.NetConnectionID -match 'Ethernet') -and ($_.NetConnectionID -notmatch 'Wireless') -and ($_.Name -notmatch 'Virtual') } -ErrorAction 'SilentlyContinue'
		[boolean]$onNetwork = $false
		If ($networkConnected)
		{
			Write-Log -Message 'Wired network connection found.' -Source ${CmdletName}
			[boolean]$onNetwork = $true
		}
		Else
		{
			Write-Log -Message 'Wired network connection not found.' -Source ${CmdletName}
		}
		
		Write-Output -InputObject $onNetwork
	}
	End
	{
		Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -Footer
	}
}
#endregion

#region Function Test-PowerPoint
Function Test-PowerPoint
{
<#
.SYNOPSIS
	Tests whether PowerPoint is running in either fullscreen slideshow mode or presentation mode.
.DESCRIPTION
	Tests whether someone is presenting using PowerPoint in either fullscreen slideshow mode or presentation mode.
.DEPENDENCIES
	Get-WindowTitle
	Resolve-Error
.EXAMPLE
	Test-PowerPoint
.NOTES
	This function can only execute detection logic if the process is in interactive mode.
	There is a possiblity of a false positive if the PowerPoint filename starts with "PowerPoint Slide Show".
.LINK
	http://psappdeploytoolkit.com
#>
	[CmdletBinding()]
	Param (
	)
	
	Begin
	{
		## Get the name of this function and write header
		[string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
		Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -CmdletBoundParameters $PSBoundParameters -Header
	}
	Process
	{
		Try
		{
			Write-Log -Message 'Check if PowerPoint is in either fullscreen slideshow mode or presentation mode...' -Source ${CmdletName}
			Try
			{
				[Diagnostics.Process[]]$PowerPointProcess = Get-Process -ErrorAction 'Stop' | Where-Object { $_.ProcessName -eq 'POWERPNT' }
				If ($PowerPointProcess)
				{
					[boolean]$IsPowerPointRunning = $true
					Write-Log -Message 'PowerPoint application is running.' -Source ${CmdletName}
				}
				Else
				{
					[boolean]$IsPowerPointRunning = $false
					Write-Log -Message 'PowerPoint application is not running.' -Source ${CmdletName}
				}
			}
			Catch
			{
				Throw
			}
			
			[nullable[boolean]]$IsPowerPointFullScreen = $false
			If ($IsPowerPointRunning)
			{
				## Detect if PowerPoint is in fullscreen mode or Presentation Mode, detection method only works if process is interactive
				If ([Environment]::UserInteractive)
				{
					#  Check if "POWERPNT" process has a window with a title that begins with "PowerPoint Slide Show" or "Powerpoint-" for non-English language systems.
					#  There is a possiblity of a false positive if the PowerPoint filename starts with "PowerPoint Slide Show"
					[psobject]$PowerPointWindow = Get-WindowTitle -GetAllWindowTitles | Where-Object { $_.WindowTitle -match '^PowerPoint Slide Show' -or $_.WindowTitle -match '^PowerPoint-' } | Where-Object { $_.ParentProcess -eq 'POWERPNT' } | Select-Object -First 1
					If ($PowerPointWindow)
					{
						[nullable[boolean]]$IsPowerPointFullScreen = $true
						Write-Log -Message 'Detected that PowerPoint process [POWERPNT] has a window with a title that beings with [PowerPoint Slide Show] or [PowerPoint-].' -Source ${CmdletName}
					}
					Else
					{
						Write-Log -Message 'Detected that PowerPoint process [POWERPNT] does not have a window with a title that beings with [PowerPoint Slide Show] or [PowerPoint-].' -Source ${CmdletName}
						Try
						{
							[int32[]]$PowerPointProcessIDs = $PowerPointProcess | Select-Object -ExpandProperty 'Id' -ErrorAction 'Stop'
							Write-Log -Message "PowerPoint process [POWERPNT] has process id(s) [$($PowerPointProcessIDs -join ', ')]." -Source ${CmdletName}
						}
						Catch
						{
							Write-Log -Message "Unable to retrieve process id(s) for [POWERPNT] process. `n$(Resolve-Error)" -Severity 2 -Source ${CmdletName}
						}
					}
					
					## If previous detection method did not detect PowerPoint in fullscreen mode, then check if PowerPoint is in Presentation Mode (check only works on Windows Vista or higher)
					If ((-not $IsPowerPointFullScreen) -and (([version]$envOSVersion).Major -gt 5))
					{
						#  Note: below method does not detect PowerPoint presentation mode if the presentation is on a monitor that does not have current mouse input control
						[string]$UserNotificationState = [PSADT.UiAutomation]::GetUserNotificationState()
						Write-Log -Message "Detected user notification state [$UserNotificationState]." -Source ${CmdletName}
						Switch ($UserNotificationState)
						{
							'PresentationMode' {
								Write-Log -Message "Detected that system is in [Presentation Mode]." -Source ${CmdletName}
								[nullable[boolean]]$IsPowerPointFullScreen = $true
							}
							'FullScreenOrPresentationModeOrLoginScreen' {
								If (([string]$PowerPointProcessIDs) -and ($PowerPointProcessIDs -contains [PSADT.UIAutomation]::GetWindowThreadProcessID([PSADT.UIAutomation]::GetForeGroundWindow())))
								{
									Write-Log -Message "Detected that fullscreen foreground window matches PowerPoint process id." -Source ${CmdletName}
									[nullable[boolean]]$IsPowerPointFullScreen = $true
								}
							}
						}
					}
				}
				Else
				{
					[nullable[boolean]]$IsPowerPointFullScreen = $null
					Write-Log -Message 'Unable to run check to see if PowerPoint is in fullscreen mode or Presentation Mode because current process is not interactive. Configure script to run in interactive mode in your deployment tool. If using SCCM Application Model, then make sure "Allow users to view and interact with the program installation" is selected. If using SCCM Package Model, then make sure "Allow users to interact with this program" is selected.' -Severity 2 -Source ${CmdletName}
				}
			}
		}
		Catch
		{
			[nullable[boolean]]$IsPowerPointFullScreen = $null
			Write-Log -Message "Failed check to see if PowerPoint is running in fullscreen slideshow mode. `n$(Resolve-Error)" -Severity 3 -Source ${CmdletName}
		}
	}
	End
	{
		Write-Log -Message "PowerPoint is running in fullscreen mode [$IsPowerPointFullScreen]." -Source ${CmdletName}
		Write-Output -InputObject $IsPowerPointFullScreen
		Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -Footer
	}
}
#endregion

#region Function New-Shortcut
Function New-Shortcut
{
<#
.SYNOPSIS
	Creates a new .lnk or .url type shortcut
.DESCRIPTION
	Creates a new shortcut .lnk or .url file, with configurable options
.DEPENDENCIES
.PARAMETER Path
	Path to save the shortcut
.PARAMETER TargetPath
	Target path or URL that the shortcut launches
.PARAMETER Arguments
	Arguments to be passed to the target path
.PARAMETER IconLocation
	Location of the icon used for the shortcut
.PARAMETER IconIndex
	Executables, DLLs, ICO files with multiple icons need the icon index to be specified
.PARAMETER Description
	Description of the shortcut
.PARAMETER WorkingDirectory
	Working Directory to be used for the target path
.PARAMETER WindowStyle
	Windows style of the application. Options: Normal, Maximized, Minimized. Default is: Normal.
.PARAMETER RunAsAdmin
	Set shortcut to run program as administrator. This option will prompt user to elevate when executing shortcut.
.PARAMETER Hotkey
    Create a Hotkey to launch the shortcut, e.g. "CTRL+SHIFT+F"
.PARAMETER ContinueOnError
	Continue if an error is encountered. Default is: $true.
.EXAMPLE
	New-Shortcut -Path "$envProgramData\Microsoft\Windows\Start Menu\My Shortcut.lnk" -TargetPath "$envWinDir\system32\notepad.exe" -IconLocation "$envWinDir\system32\notepad.exe" -Description 'Notepad' -WorkingDirectory "$envHomeDrive\$envHomePath"
.NOTES
.LINK
	http://psappdeploytoolkit.com
#>
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $true)]
		[ValidateNotNullorEmpty()]
		[string]$Path,
		[Parameter(Mandatory = $true)]
		[ValidateNotNullorEmpty()]
		[string]$TargetPath,
		[Parameter(Mandatory = $false)]
		[ValidateNotNullOrEmpty()]
		[string]$Arguments,
		[Parameter(Mandatory = $false)]
		[ValidateNotNullorEmpty()]
		[string]$IconLocation,
		[Parameter(Mandatory = $false)]
		[ValidateNotNullorEmpty()]
		[string]$IconIndex,
		[Parameter(Mandatory = $false)]
		[ValidateNotNullOrEmpty()]
		[string]$Description,
		[Parameter(Mandatory = $false)]
		[ValidateNotNullOrEmpty()]
		[string]$WorkingDirectory,
		[Parameter(Mandatory = $false)]
		[ValidateSet('Normal', 'Maximized', 'Minimized')]
		[string]$WindowStyle,
		[Parameter(Mandatory = $false)]
		[switch]$RunAsAdmin,
		[Parameter(Mandatory = $false)]
		[ValidateNotNullorEmpty()]
		[string]$Hotkey,
		[Parameter(Mandatory = $false)]
		[ValidateNotNullOrEmpty()]
		[boolean]$ContinueOnError = $true
	)
	
	Begin
	{
		## Get the name of this function and write header
		[string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
		Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -CmdletBoundParameters $PSBoundParameters -Header
		
		If (-not $Shell) { [__comobject]$Shell = New-Object -ComObject 'WScript.Shell' -ErrorAction 'Stop' }
	}
	Process
	{
		Try
		{
			Try
			{
				[IO.FileInfo]$Path = [IO.FileInfo]$Path
				[string]$PathDirectory = $Path.DirectoryName
				
				If (-not (Test-Path -LiteralPath $PathDirectory -PathType 'Container' -ErrorAction 'Stop'))
				{
					Write-Log -Message "Create shortcut directory [$PathDirectory]." -Source ${CmdletName}
					$null = New-Item -Path $PathDirectory -ItemType 'Directory' -Force -ErrorAction 'Stop'
				}
			}
			Catch
			{
				Write-Log -Message "Failed to create shortcut directory [$PathDirectory]. `n$(Resolve-Error)" -Severity 3 -Source ${CmdletName}
				Throw
			}
			
			Write-Log -Message "Create shortcut [$($path.FullName)]." -Source ${CmdletName}
			If (($path.FullName).ToLower().EndsWith('.url'))
			{
				[string[]]$URLFile = '[InternetShortcut]'
				$URLFile += "URL=$targetPath"
				If ($iconIndex) { $URLFile += "IconIndex=$iconIndex" }
				If ($IconLocation) { $URLFile += "IconFile=$iconLocation" }
				$URLFile | Out-File -FilePath $path.FullName -Force -Encoding 'default' -ErrorAction 'Stop'
			}
			ElseIf (($path.FullName).ToLower().EndsWith('.lnk'))
			{
				If (($iconLocation -and $iconIndex) -and (-not ($iconLocation.Contains(','))))
				{
					$iconLocation = $iconLocation + ",$iconIndex"
				}
				Switch ($windowStyle)
				{
					'Normal' { $windowStyleInt = 1 }
					'Maximized' { $windowStyleInt = 3 }
					'Minimized' { $windowStyleInt = 7 }
					Default { $windowStyleInt = 1 }
				}
				$shortcut = $shell.CreateShortcut($path.FullName)
				$shortcut.TargetPath = $targetPath
				$shortcut.Arguments = $arguments
				$shortcut.Description = $description
				$shortcut.WorkingDirectory = $workingDirectory
				$shortcut.WindowStyle = $windowStyleInt
				If ($hotkey) { $shortcut.Hotkey = $hotkey }
				If ($iconLocation) { $shortcut.IconLocation = $iconLocation }
				$shortcut.Save()
				
				## Set shortcut to run program as administrator
				If ($RunAsAdmin)
				{
					Write-Log -Message 'Set shortcut to run program as administrator.' -Source ${CmdletName}
					$TempFileName = [IO.Path]::GetRandomFileName()
					$TempFile = [IO.FileInfo][IO.Path]::Combine($Path.Directory, $TempFileName)
					$Writer = New-Object -TypeName 'System.IO.FileStream' -ArgumentList ($TempFile, ([IO.FileMode]::Create)) -ErrorAction 'Stop'
					$Reader = $Path.OpenRead()
					While ($Reader.Position -lt $Reader.Length)
					{
						$Byte = $Reader.ReadByte()
						If ($Reader.Position -eq 22) { $Byte = 34 }
						$Writer.WriteByte($Byte)
					}
					$Reader.Close()
					$Writer.Close()
					$Path.Delete()
					$null = Rename-Item -Path $TempFile -NewName $Path.Name -Force -ErrorAction 'Stop'
				}
			}
		}
		Catch
		{
			Write-Log -Message "Failed to create shortcut [$($path.FullName)]. `n$(Resolve-Error)" -Severity 3 -Source ${CmdletName}
			If (-not $ContinueOnError)
			{
				Throw "Failed to create shortcut [$($path.FullName)]: $($_.Exception.Message)"
			}
		}
	}
	End
	{
		Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -Footer
	}
}
#endregion

#region Function Install-MSUpdates
Function Install-MSUpdates
{
<#
.SYNOPSIS
	Install all Microsoft Updates in a given directory.
.DESCRIPTION
	Install all Microsoft Updates of type ".exe", ".msu", or ".msp" in a given directory (recursively search directory).
.DEPENDENCIES
	Execute-MSI
	Execute-Process
	Test-MSUpdates
.PARAMETER Directory
	Directory containing the updates.
.EXAMPLE
	Install-MSUpdates -Directory "$dirFiles\MSUpdates"
.NOTES
.LINK
	http://psappdeploytoolkit.com
#>
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $true)]
		[ValidateNotNullorEmpty()]
		[string]$Directory
	)
	
	Begin
	{
		## Get the name of this function and write header
		[string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
		Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -CmdletBoundParameters $PSBoundParameters -Header
	}
	Process
	{
		Write-Log -Message "Recursively install all Microsoft Updates in directory [$Directory]." -Source ${CmdletName}
		
		## KB Number pattern match
		$kbPattern = '(?i)kb\d{6,8}'
		
		## Get all hotfixes and install if required
		[IO.FileInfo[]]$files = Get-ChildItem -LiteralPath $Directory -Recurse -Include ('*.exe', '*.msu', '*.msp')
		ForEach ($file in $files)
		{
			If ($file.Name -match 'redist')
			{
				[version]$redistVersion = [Diagnostics.FileVersionInfo]::GetVersionInfo($file.FullName).ProductVersion
				[string]$redistDescription = [Diagnostics.FileVersionInfo]::GetVersionInfo($file.FullName).FileDescription
				
				Write-Log -Message "Install [$redistDescription $redistVersion]..." -Source ${CmdletName}
				#  Handle older redistributables (ie, VC++ 2005)
				If ($redistDescription -match 'Win32 Cabinet Self-Extractor')
				{
					Execute-Process -Path $file.FullName -Parameters '/q' -WindowStyle 'Hidden' -ContinueOnError $true
				}
				Else
				{
					Execute-Process -Path $file.FullName -Parameters '/quiet /norestart' -WindowStyle 'Hidden' -ContinueOnError $true
				}
			}
			Else
			{
				#  Get the KB number of the file
				[string]$kbNumber = [regex]::Match($file.Name, $kbPattern).ToString()
				If (-not $kbNumber) { Continue }
				
				#  Check to see whether the KB is already installed
				If (-not (Test-MSUpdates -KBNumber $kbNumber))
				{
					Write-Log -Message "KB Number [$KBNumber] was not detected and will be installed." -Source ${CmdletName}
					Switch ($file.Extension)
					{
						#  Installation type for executables (i.e., Microsoft Office Updates)
						'.exe' { Execute-Process -Path $file.FullName -Parameters '/quiet /norestart' -WindowStyle 'Hidden' -ContinueOnError $true }
						#  Installation type for Windows updates using Windows Update Standalone Installer
						'.msu' { Execute-Process -Path 'wusa.exe' -Parameters "`"$($file.FullName)`" /quiet /norestart" -WindowStyle 'Hidden' -ContinueOnError $true }
						#  Installation type for Windows Installer Patch
						'.msp' { Execute-MSI -Action 'Patch' -Path $file.FullName -ContinueOnError $true }
					}
				}
				Else
				{
					Write-Log -Message "KB Number [$kbNumber] is already installed. Continue..." -Source ${CmdletName}
				}
			}
		}
	}
	End
	{
		Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -Footer
	}
}
#endregion

#region Function Set-MsiProperty
Function Set-MsiProperty
{
<#
.SYNOPSIS
	Set a property in the MSI property table.
.DESCRIPTION
	Set a property in the MSI property table.
.DEPENDENCIES
	Invoke-ObjectMethod
	Resolve-Error
.PARAMETER DataBase
	Specify a ComObject representing an MSI database opened in view/modify/update mode.
.PARAMETER PropertyName
	The name of the property to be set/modified.
.PARAMETER PropertyValue
	The value of the property to be set/modified.
.PARAMETER ContinueOnError
	Continue if an error is encountered. Default is: $true.
.EXAMPLE
	Set-MsiProperty -DataBase $TempMsiPathDatabase -PropertyName 'ALLUSERS' -PropertyValue '1'
.NOTES
	This is an internal script function and should typically not be called directly.
.LINK
	http://psappdeploytoolkit.com
#>
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $true)]
		[ValidateNotNullorEmpty()]
		[__comobject]$DataBase,
		[Parameter(Mandatory = $true)]
		[ValidateNotNullorEmpty()]
		[string]$PropertyName,
		[Parameter(Mandatory = $true)]
		[ValidateNotNullorEmpty()]
		[string]$PropertyValue,
		[Parameter(Mandatory = $false)]
		[ValidateNotNullorEmpty()]
		[boolean]$ContinueOnError = $true
	)
	
	Begin
	{
		## Get the name of this function and write header
		[string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
		
		Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -CmdletBoundParameters $PSBoundParameters -Header
	}
	Process
	{
		Try
		{
			Write-Log -Message "Set the MSI Property Name [$PropertyName] with Property Value [$PropertyValue]." -Source ${CmdletName}
			
			## Open the requested table view from the database
			[__comobject]$View = Invoke-ObjectMethod -InputObject $DataBase -MethodName 'OpenView' -ArgumentList @("SELECT * FROM Property WHERE Property='$PropertyName'")
			$null = Invoke-ObjectMethod -InputObject $View -MethodName 'Execute'
			
			## Retrieve the requested property from the requested table.
			#  https://msdn.microsoft.com/en-us/library/windows/desktop/aa371136(v=vs.85).aspx
			[__comobject]$Record = Invoke-ObjectMethod -InputObject $View -MethodName 'Fetch'
			
			## Close the previous view on the MSI database
			$null = Invoke-ObjectMethod -InputObject $View -MethodName 'Close' -ArgumentList @()
			$null = [Runtime.Interopservices.Marshal]::ReleaseComObject($View)
			
			## Set the MSI property
			If ($Record)
			{
				#  If the property already exists, then create the view for updating the property
				[__comobject]$View = Invoke-ObjectMethod -InputObject $DataBase -MethodName 'OpenView' -ArgumentList @("UPDATE Property SET Value='$PropertyValue' WHERE Property='$PropertyName'")
			}
			Else
			{
				#  If property does not exist, then create view for inserting the property
				[__comobject]$View = Invoke-ObjectMethod -InputObject $DataBase -MethodName 'OpenView' -ArgumentList @("INSERT INTO Property (Property, Value) VALUES ('$PropertyName','$PropertyValue')")
			}
			#  Execute the view to set the MSI property
			$null = Invoke-ObjectMethod -InputObject $View -MethodName 'Execute'
		}
		Catch
		{
			Write-Log -Message "Failed to set the MSI Property Name [$PropertyName] with Property Value [$PropertyValue]. `n$(Resolve-Error)" -Severity 3 -Source ${CmdletName}
			If (-not $ContinueOnError)
			{
				Throw "Failed to set the MSI Property Name [$PropertyName] with Property Value [$PropertyValue]: $($_.Exception.Message)"
			}
		}
		Finally
		{
			Try
			{
				If ($View)
				{
					$null = Invoke-ObjectMethod -InputObject $View -MethodName 'Close' -ArgumentList @()
					$null = [Runtime.Interopservices.Marshal]::ReleaseComObject($View)
				}
			}
			Catch { }
		}
	}
	End
	{
		Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -Footer
	}
}
#endregion

#region Function New-ZipFile
Function New-ZipFile
{
<#
.SYNOPSIS
	Create a new zip archive or add content to an existing archive.
.DESCRIPTION
	Create a new zip archive or add content to an existing archive by using the Shell object .CopyHere method.
.PARAMETER DestinationArchiveDirectoryPath
	The path to the directory path where the zip archive will be saved.
.PARAMETER DestinationArchiveFileName
	The name of the zip archive.
.PARAMETER SourceDirectoryPath
	The path to the directory to be archived, specified as absolute paths.
.PARAMETER SourceFilePath
	The path to the file to be archived, specified as absolute paths.
.PARAMETER RemoveSourceAfterArchiving
	Remove the source path after successfully archiving the content. Default is: $false.
.PARAMETER OverWriteArchive
	Overwrite the destination archive path if it already exists. Default is: $false.
.PARAMETER ContinueOnError
	Continue if an error is encountered. Default: $true.
.EXAMPLE
	New-ZipFile -DestinationArchiveDirectoryPath 'E:\Testing' -DestinationArchiveFileName 'TestingLogs.zip' -SourceDirectory 'E:\Testing\Logs'
.NOTES
	This is an internal script function and should typically not be called directly.
.LINK
	http://psappdeploytoolkit.com
#>
	[CmdletBinding(DefaultParameterSetName = 'CreateFromDirectory')]
	Param (
		[Parameter(Mandatory = $true, Position = 0)]
		[ValidateNotNullorEmpty()]
		[string]$DestinationArchiveDirectoryPath,
		[Parameter(Mandatory = $true, Position = 1)]
		[ValidateNotNullorEmpty()]
		[string]$DestinationArchiveFileName,
		[Parameter(Mandatory = $true, Position = 2, ParameterSetName = 'CreateFromDirectory')]
		[ValidateScript({ Test-Path -LiteralPath $_ -PathType 'Container' })]
		[string[]]$SourceDirectoryPath,
		[Parameter(Mandatory = $true, Position = 2, ParameterSetName = 'CreateFromFile')]
		[ValidateScript({ Test-Path -LiteralPath $_ -PathType 'Leaf' })]
		[string[]]$SourceFilePath,
		[Parameter(Mandatory = $false, Position = 3)]
		[ValidateNotNullorEmpty()]
		[switch]$RemoveSourceAfterArchiving = $false,
		[Parameter(Mandatory = $false, Position = 4)]
		[ValidateNotNullorEmpty()]
		[switch]$OverWriteArchive = $false,
		[Parameter(Mandatory = $false, Position = 5)]
		[ValidateNotNullorEmpty()]
		[boolean]$ContinueOnError = $true
	)
	
	Begin
	{
		## Get the name of this function and write header
		[string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
		
		Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -CmdletBoundParameters $PSBoundParameters -Header
	}
	Process
	{
		Try
		{
			## Get the full destination path where the archive will be stored
			[string]$DestinationPath = Join-Path -Path $DestinationArchiveDirectoryPath -ChildPath $DestinationArchiveFileName -ErrorAction 'Stop'
			Write-Log -Message "Create a zip archive with the requested content at destination path [$DestinationPath]." -Source ${CmdletName}
			
			## If the destination archive already exists, delete it if the -OverWriteArchive option was selected
			If (($OverWriteArchive) -and (Test-Path -LiteralPath $DestinationPath))
			{
				Write-Log -Message "An archive at the destination path already exists, deleting file [$DestinationPath]." -Source ${CmdletName}
				$null = Remove-Item -LiteralPath $DestinationPath -Force -ErrorAction 'Stop'
			}
			
			## If archive file does not exist, then create a zero-byte zip archive
			If (-not (Test-Path -LiteralPath $DestinationPath))
			{
				## Create a zero-byte file
				Write-Log -Message "Create a zero-byte file [$DestinationPath]." -Source ${CmdletName}
				$null = New-Item -Path $DestinationArchiveDirectoryPath -Name $DestinationArchiveFileName -ItemType 'File' -Force -ErrorAction 'Stop'
				
				## Write the file header for a zip file to the zero-byte file
				[byte[]]$ZipArchiveByteHeader = 80, 75, 5, 6, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
				[IO.FileStream]$FileStream = New-Object -TypeName 'System.IO.FileStream' -ArgumentList ($DestinationPath, ([IO.FileMode]::Create))
				[IO.BinaryWriter]$BinaryWriter = New-Object -TypeName 'System.IO.BinaryWriter' -ArgumentList ($FileStream)
				Write-Log -Message "Write the file header for a zip archive to the zero-byte file [$DestinationPath]." -Source ${CmdletName}
				$null = $BinaryWriter.Write($ZipArchiveByteHeader)
				$BinaryWriter.Close()
				$FileStream.Close()
			}
			
			## Create a Shell object
			[__comobject]$ShellApp = New-Object -ComObject 'Shell.Application' -ErrorAction 'Stop'
			## Create an object representing the archive file
			[__comobject]$Archive = $ShellApp.NameSpace($DestinationPath)
			
			## Create the archive file
			If ($PSCmdlet.ParameterSetName -eq 'CreateFromDirectory')
			{
				## Create the archive file from a source directory
				ForEach ($Directory in $SourceDirectoryPath)
				{
					Try
					{
						#  Create an object representing the source directory
						[__comobject]$CreateFromDirectory = $ShellApp.NameSpace($Directory)
						#  Copy all of the files and folders from the source directory to the archive
						$null = $Archive.CopyHere($CreateFromDirectory.Items())
						#  Wait for archive operation to complete. Archive file count property returns 0 if archive operation is in progress.
						Write-Log -Message "Compressing [$($CreateFromDirectory.Count)] file(s) in source directory [$Directory] to destination path [$DestinationPath]..." -Source ${CmdletName}
						Do { Start-Sleep -Milliseconds 250 }
						While ($Archive.Items().Count -eq 0)
					}
					Finally
					{
						#  Release the ComObject representing the source directory
						$null = [Runtime.Interopservices.Marshal]::ReleaseComObject($CreateFromDirectory)
					}
					
					#  If option was selected, recursively delete the source directory after successfully archiving the contents
					If ($RemoveSourceAfterArchiving)
					{
						Try
						{
							Write-Log -Message "Recursively delete the source directory [$Directory] as contents have been successfully archived." -Source ${CmdletName}
							$null = Remove-Item -LiteralPath $Directory -Recurse -Force -ErrorAction 'Stop'
						}
						Catch
						{
							Write-Log -Message "Failed to recursively delete the source directory [$Directory]. `n$(Resolve-Error)" -Severity 2 -Source ${CmdletName}
						}
					}
				}
			}
			Else
			{
				## Create the archive file from a list of one or more files
				[IO.FileInfo[]]$SourceFilePath = [IO.FileInfo[]]$SourceFilePath
				ForEach ($File in $SourceFilePath)
				{
					#  Copy the files and folders from the source directory to the archive
					$null = $Archive.CopyHere($File.FullName)
					#  Wait for archive operation to complete. Archive file count property returns 0 if archive operation is in progress.
					Write-Log -Message "Compressing file [$($File.FullName)] to destination path [$DestinationPath]..." -Source ${CmdletName}
					Do { Start-Sleep -Milliseconds 250 }
					While ($Archive.Items().Count -eq 0)
					
					#  If option was selected, delete the source file after successfully archiving the content
					If ($RemoveSourceAfterArchiving)
					{
						Try
						{
							Write-Log -Message "Delete the source file [$($File.FullName)] as it has been successfully archived." -Source ${CmdletName}
							$null = Remove-Item -LiteralPath $File.FullName -Force -ErrorAction 'Stop'
						}
						Catch
						{
							Write-Log -Message "Failed to delete the source file [$($File.FullName)]. `n$(Resolve-Error)" -Severity 2 -Source ${CmdletName}
						}
					}
				}
			}
			
			## If the archive was created in session 0 or by an Admin, then it may only be readable by elevated users.
			#  Apply the parent folder's permissions to the archive file to fix the problem.
			Write-Log -Message "If the archive was created in session 0 or by an Admin, then it may only be readable by elevated users. Apply permissions from parent folder [$DestinationArchiveDirectoryPath] to file [$DestinationPath]." -Source ${CmdletName}
			Try
			{
				[Security.AccessControl.DirectorySecurity]$DestinationArchiveDirectoryPathAcl = Get-Acl -Path $DestinationArchiveDirectoryPath -ErrorAction 'Stop'
				Set-Acl -Path $DestinationPath -AclObject $DestinationArchiveDirectoryPathAcl -ErrorAction 'Stop'
			}
			Catch
			{
				Write-Log -Message "Failed to apply parent folder's [$DestinationArchiveDirectoryPath] permissions to file [$DestinationPath]. `n$(Resolve-Error)" -Severity 2 -Source ${CmdletName}
			}
		}
		Catch
		{
			Write-Log -Message "Failed to archive the requested file(s). `n$(Resolve-Error)" -Severity 3 -Source ${CmdletName}
			If (-not $ContinueOnError)
			{
				Throw "Failed to archive the requested file(s): $($_.Exception.Message)"
			}
		}
		Finally
		{
			## Release the ComObject representing the archive
			If ($Archive) { $null = [Runtime.Interopservices.Marshal]::ReleaseComObject($Archive) }
		}
	}
	End
	{
		Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -Footer
	}
}
#endregion

#region Function Expand-ZipFile
Function Expand-ZipFile
{
<#
.SYNOPSIS

Extracts ZIP file contents.

.DESCRIPTION

Extracts the contents of a ZIP file to a given destination.

.PARAMETER Path

Specify the ZIP file name. Full file path is not required as $dirFiles will be used as the default file path. 

.PARAMETER Destination

Specify the destination path. Default: $dirFiles.

.PARAMETER Force

Force file overwrite if $Destination is not default.
	
.INPUTS

None

You cannot pipe objects to this function.

.EXAMPLE

Expand-ZipFile -Name "Example.zip"

Extracts the contents from $dirFiles\Example.zip to $dirFiles.

.EXAMPLE

Expand-ZipFile -Name "C:\Windows\Example.zip" -Destination "C:\Temp\Extraction" -Force

Deletes the destination folder "C:\Temp\Extraction" and then extracts the contents from "C:\Windows\Example.zip" to "C:\Temp\Extraction".

.NOTES

Currently limited to only extract ZIP archive files.
	
.LINK

#>
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $true, Position = 1)]
		[Alias('Name')]
		[ValidateNotNullorEmpty()]
		[String]$Path,
		[Parameter(Mandatory = $false, Position = 2)]
		[ValidateNotNullorEmpty()]
		[String]$Destination = $dirFiles,
		[Parameter(Mandatory = $false, Position = 3)]
		[ValidateNotNullorEmpty()]
		[Switch]$Force = $false
	)
	
	Begin
	{
		## Get the name of this function and write header
		[String]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
		Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -CmdletBoundParameters $PSBoundParameters -Header
	}
	Process
	{		
		# Validate Path has an extension
		if (-not [IO.Path]::HasExtension($Path))
		{
			Write-Log -Message "Error: [$Path] is not a file. Please specify a file name with extension." -Severity 3 -Source ${CmdletName} -LogType CMTrace
			Return
		}
		# Validate the extension is .ZIP
		if ([IO.Path]::GetExtension($Path) -ne '.zip')
		{
			Write-Log -Message "Error: [$Path] is not a ZIP file. ZIP archives are the only supported format at his time." -Severity 3 -Source ${CmdletName} -LogType CMTrace
			Return
		}
		# Validate is Path is rooted (full path)
		if ([IO.Path]::IsPathRooted($Path))
		{
			if (-not (Test-Path -Path $Path))
			{
				Write-Log -Message "Error: [$Path] doesn't exist." -Severity 3 -Source ${CmdletName} -LogType CMTrace
				Return
			}
			Write-Log -Message "[$Path] is fully qualified." -Source ${CmdletName} -LogType CMTrace
		}
		else
		{
			# Add dirFiles to Path and resolve
			Try
			{
				[String]$Path = Join-Path -Path $dirFiles -ChildPath $Path -Resolve -ErrorAction Stop
			}
			catch [Exception] {
				Write-Log -Message "Error: $($_.Exception.Message)" -Severity 3 -Source ${CmdletName} -LogType CMTrace
				Return
			}
			Write-Log -Message "[$Path] is fully qualified." -Source ${CmdletName} -LogType CMTrace
		}
		## Validate Force option
		If ($Force)
		{
			## Validate destination folder
			if (Test-Path -LiteralPath $Destination)
			{
				## Ensure destination is not DirFiles
				if ($Destination -ne $dirFiles)
				{
					Write-Log -Message "An archive at the destination path already exists, deleting folder [$Destination]." -Source ${CmdletName} -LogType CMTrace
					Remove-Folder -Path $Destination
				}
				else
				{
					Write-Log -Message "Warning: [$Destination] is set to [$dirFiles]. Skipping folder removal. If any files from the zip file already exist, the ZIP extraction will fail." -Severity 2 -Source ${CmdletName} -LogType CMTrace
				}
			}
			else
			{
				Write-Log -Message "[$Destination] does not exist. Skipping folder removal." -Source ${CmdletName} -LogType CMTrace
			}
		}
		Try
		{
			# Add the compression type to the session
			Add-Type -Assembly 'System.IO.Compression.FileSystem'
			# Open the archive for reading
			$archive = [System.IO.Compression.ZipFile]::Open($Path, 'read')
			# Extract the archive contents to the Destination
			Write-Log -Message "Extracting [$Path] to [$Destination]." -Source ${CmdletName} -LogType CMTrace
			[System.IO.Compression.ZipFileExtensions]::ExtractToDirectory($archive, $Destination)
			# Close the archive
			$archive.Dispose()
			Write-Log -Message "[$Path] successfully extracted to [$Destination]." -Source ${CmdletName} -LogType CMTrace
		}
		Catch [System.Exception]
		{
			Write-Log -Message "There was an error expanding [$Path] to [$Destination]: $($_.Exception.Message)" -Severity 3 -Source ${CmdletName} -LogType CMTrace
		}
	}
	End
	{
		Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -Footer
	}
}
#endregion

#region Function Get-PEFileArchitecture
Function Get-PEFileArchitecture
{
<#
.SYNOPSIS
	Determine if a PE file is a 32-bit or a 64-bit file.
.DESCRIPTION
	Determine if a PE file is a 32-bit or a 64-bit file by examining the file's image file header.
	PE file extensions: .exe, .dll, .ocx, .drv, .sys, .scr, .efi, .cpl, .fon
.DEPENDENCIES
	Resolve-Error
.PARAMETER FilePath
	Path to the PE file to examine.
.PARAMETER ContinueOnError
	Continue if an error is encountered. Default is: $true.
.PARAMETER PassThru
	Get the file object, attach a property indicating the file binary type, and write to pipeline
.EXAMPLE
	Get-PEFileArchitecture -FilePath "$env:windir\notepad.exe"
.NOTES
	This is an internal script function and should typically not be called directly.
.LINK
#>
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
		[ValidateScript({ Test-Path -LiteralPath $_ -PathType 'Leaf' })]
		[IO.FileInfo[]]$FilePath,
		[Parameter(Mandatory = $false)]
		[ValidateNotNullorEmpty()]
		[boolean]$ContinueOnError = $true,
		[Parameter(Mandatory = $false)]
		[switch]$PassThru
	)
	
	Begin
	{
		## Get the name of this function and write header
		[string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
		Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -CmdletBoundParameters $PSBoundParameters -Header
		
		[string[]]$PEFileExtensions = '.exe', '.dll', '.ocx', '.drv', '.sys', '.scr', '.efi', '.cpl', '.fon'
		[int32]$MACHINE_OFFSET = 4
		[int32]$PE_POINTER_OFFSET = 60
	}
	Process
	{
		ForEach ($Path in $filePath)
		{
			Try
			{
				If ($PEFileExtensions -notcontains $Path.Extension)
				{
					Throw "Invalid file type. Please specify one of the following PE file types: $($PEFileExtensions -join ', ')"
				}
				
				[byte[]]$data = New-Object -TypeName 'System.Byte[]' -ArgumentList 4096
				$stream = New-Object -TypeName 'System.IO.FileStream' -ArgumentList ($Path.FullName, 'Open', 'Read')
				$null = $stream.Read($data, 0, 4096)
				$stream.Flush()
				$stream.Close()
				
				[int32]$PE_HEADER_ADDR = [BitConverter]::ToInt32($data, $PE_POINTER_OFFSET)
				[uint16]$PE_IMAGE_FILE_HEADER = [BitConverter]::ToUInt16($data, $PE_HEADER_ADDR + $MACHINE_OFFSET)
				Switch ($PE_IMAGE_FILE_HEADER)
				{
					0 { $PEArchitecture = 'Native' } # The contents of this file are assumed to be applicable to any machine type
					0x014c { $PEArchitecture = '32BIT' } # File for Windows 32-bit systems
					0x0200 { $PEArchitecture = 'Itanium-x64' } # File for Intel Itanium x64 processor family
					0x8664 { $PEArchitecture = '64BIT' } # File for Windows 64-bit systems
					Default { $PEArchitecture = 'Unknown' }
				}
				Write-Log -Message "File [$($Path.FullName)] has a detected file architecture of [$PEArchitecture]." -Source ${CmdletName}
				
				If ($PassThru)
				{
					#  Get the file object, attach a property indicating the type, and write to pipeline
					Get-Item -LiteralPath $Path.FullName -Force | Add-Member -MemberType 'NoteProperty' -Name 'BinaryType' -Value $PEArchitecture -Force -PassThru | Write-Output
				}
				Else
				{
					Write-Output -InputObject $PEArchitecture
				}
			}
			Catch
			{
				Write-Log -Message "Failed to get the PE file architecture. `n$(Resolve-Error)" -Severity 3 -Source ${CmdletName}
				If (-not $ContinueOnError)
				{
					Throw "Failed to get the PE file architecture: $($_.Exception.Message)"
				}
				Continue
			}
		}
	}
	End
	{
		Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -Footer
	}
}
#endregion

#region Function Test-MSUpdates
Function Test-MSUpdates
{
<#
.SYNOPSIS
	Test whether a Microsoft Windows update is installed.
.DESCRIPTION
	Test whether a Microsoft Windows update is installed.
.PARAMETER KBNumber
	KBNumber of the update.
.PARAMETER ContinueOnError
	Suppress writing log message to console on failure to write message to log file. Default is: $true.
.EXAMPLE
	Test-MSUpdates -KBNumber 'KB2549864'
.NOTES
.LINK
	http://psappdeploytoolkit.com
#>
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $true, Position = 0, HelpMessage = 'Enter the KB Number for the Microsoft Update')]
		[ValidateNotNullorEmpty()]
		[string]$KBNumber,
		[Parameter(Mandatory = $false, Position = 1)]
		[ValidateNotNullorEmpty()]
		[boolean]$ContinueOnError = $true
	)
	
	Begin
	{
		## Get the name of this function and write header
		[string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
		Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -CmdletBoundParameters $PSBoundParameters -Header
	}
	Process
	{
		Try
		{
			Write-Log -Message "Check if Microsoft Update [$kbNumber] is installed." -Source ${CmdletName}
			
			## Default is not found
			[boolean]$kbFound = $false
			
			## Check for update using built in PS cmdlet which uses WMI in the background to gather details
			Get-Hotfix -Id $kbNumber -ErrorAction 'SilentlyContinue' | ForEach-Object { $kbFound = $true }
			
			If (-not $kbFound)
			{
				Write-Log -Message 'Unable to detect Windows update history via Get-Hotfix cmdlet. Trying via COM object.' -Source ${CmdletName}
				
				## Check for update using ComObject method (to catch Office updates)
				[__comobject]$UpdateSession = New-Object -ComObject "Microsoft.Update.Session"
				[__comobject]$UpdateSearcher = $UpdateSession.CreateUpdateSearcher()
				#  Indicates whether the search results include updates that are superseded by other updates in the search results
				$UpdateSearcher.IncludePotentiallySupersededUpdates = $false
				#  Indicates whether the UpdateSearcher goes online to search for updates.
				$UpdateSearcher.Online = $false
				[int32]$UpdateHistoryCount = $UpdateSearcher.GetTotalHistoryCount()
				If ($UpdateHistoryCount -gt 0)
				{
					[psobject]$UpdateHistory = $UpdateSearcher.QueryHistory(0, $UpdateHistoryCount) |
					Select-Object -Property 'Title', 'Date',
								  @{ Name = 'Operation'; Expression = { Switch ($_.Operation) { 1 { 'Installation' }; 2 { 'Uninstallation' }; 3 { 'Other' } } } },
								  @{ Name = 'Status'; Expression = { Switch ($_.ResultCode) { 0 { 'Not Started' }; 1 { 'In Progress' }; 2 { 'Successful' }; 3 { 'Incomplete' }; 4 { 'Failed' }; 5 { 'Aborted' } } } },
								  'Description' |
					Sort-Object -Property 'Date' -Descending
					ForEach ($Update in $UpdateHistory)
					{
						If (($Update.Operation -ne 'Other') -and ($Update.Title -match "\($KBNumber\)"))
						{
							$LatestUpdateHistory = $Update
							Break
						}
					}
					If (($LatestUpdateHistory.Operation -eq 'Installation') -and ($LatestUpdateHistory.Status -eq 'Successful'))
					{
						Write-Log -Message "Discovered the following Microsoft Update: `n$($LatestUpdateHistory | Format-List | Out-String)" -Source ${CmdletName}
						$kbFound = $true
					}
					$null = [Runtime.Interopservices.Marshal]::ReleaseComObject($UpdateSession)
					$null = [Runtime.Interopservices.Marshal]::ReleaseComObject($UpdateSearcher)
				}
				Else
				{
					Write-Log -Message 'Unable to detect Windows update history via COM object.' -Source ${CmdletName}
				}
			}
			
			## Return Result
			If (-not $kbFound)
			{
				Write-Log -Message "Microsoft Update [$kbNumber] is not installed." -Source ${CmdletName}
				Write-Output -InputObject $false
			}
			Else
			{
				Write-Log -Message "Microsoft Update [$kbNumber] is installed." -Source ${CmdletName}
				Write-Output -InputObject $true
			}
		}
		Catch
		{
			Write-Log -Message "Failed discovering Microsoft Update [$kbNumber]. `n$(Resolve-Error)" -Severity 3 -Source ${CmdletName}
			If (-not $ContinueOnError)
			{
				Throw "Failed discovering Microsoft Update [$kbNumber]: $($_.Exception.Message)"
			}
		}
	}
	End
	{
		Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -Footer
	}
}
#endregion

#region Function Execute-ProcessAsUser
Function Execute-ProcessAsUser
{
<#
.SYNOPSIS
	Execute a process with a logged in user account, by using a scheduled task, to provide interaction with user in the SYSTEM context.
.DESCRIPTION
	Execute a process with a logged in user account, by using a scheduled task, to provide interaction with user in the SYSTEM context.
.DEPENDENCIES
	
.PARAMETER UserName
	Logged in Username under which to run the process from. Default is: The active console user. If no console user exists but users are logged in, such as on terminal servers, then the first logged-in non-console user.
.PARAMETER Path
	Path to the file being executed.
.PARAMETER Parameters
	Arguments to be passed to the file being executed.
.PARAMETER SecureParameters
	Hides all parameters passed to the executable from the Toolkit log file.
.PARAMETER RunLevel
	Specifies the level of user rights that Task Scheduler uses to run the task. The acceptable values for this parameter are:
	- HighestAvailable: Tasks run by using the highest available privileges (Admin privileges for Administrators). Default Value.
	- LeastPrivilege: Tasks run by using the least-privileged user account (LUA) privileges.
.PARAMETER Wait
	Wait for the process, launched by the scheduled task, to complete execution before accepting more input. Default is $false.
.PARAMETER PassThru
	Returns the exit code from this function or the process launched by the scheduled task.
.PARAMETER ContinueOnError
	Continue if an error is encountered. Default is $true.
.EXAMPLE
	Execute-ProcessAsUser -UserName 'CONTOSO\User' -Path "$PSHOME\powershell.exe" -Parameters "-Command & { & `"C:\Test\Script.ps1`"; Exit `$LastExitCode }" -Wait
	Execute process under a user account by specifying a username under which to execute it.
.EXAMPLE
	Execute-ProcessAsUser -Path "$PSHOME\powershell.exe" -Parameters "-Command & { & `"C:\Test\Script.ps1`"; Exit `$LastExitCode }" -Wait
	Execute process under a user account by using the default active logged in user that was detected when the toolkit was launched.
.NOTES
.LINK
	http://psappdeploytoolkit.com
#>
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $false)]
		[ValidateNotNullorEmpty()]
		[string]$UserName = $RunAsActiveUser.NTAccount,
		[Parameter(Mandatory = $true)]
		[ValidateNotNullorEmpty()]
		[string]$Path,
		[Parameter(Mandatory = $false)]
		[ValidateNotNullorEmpty()]
		[string]$Parameters = '',
		[Parameter(Mandatory = $false)]
		[switch]$SecureParameters = $false,
		[Parameter(Mandatory = $false)]
		[ValidateSet('HighestAvailable', 'LeastPrivilege')]
		[string]$RunLevel = 'HighestAvailable',
		[Parameter(Mandatory = $false)]
		[ValidateNotNullOrEmpty()]
		[switch]$Wait = $false,
		[Parameter(Mandatory = $false)]
		[switch]$PassThru = $false,
		[Parameter(Mandatory = $false)]
		[ValidateNotNullOrEmpty()]
		[boolean]$ContinueOnError = $true
	)
	
	Begin
	{
		## Get the name of this function and write header
		[string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
		Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -CmdletBoundParameters $PSBoundParameters -Header
	}
	Process
	{
		## Initialize exit code variable
		[int32]$executeProcessAsUserExitCode = 0
		
		## Confirm that the username field is not empty
		If (-not $UserName)
		{
			[int32]$executeProcessAsUserExitCode = 60009
			Write-Log -Message "The function [${CmdletName}] has a -UserName parameter that has an empty default value because no logged in users were detected when the toolkit was launched." -Severity 3 -Source ${CmdletName}
			If (-not $ContinueOnError)
			{
				Throw "The function [${CmdletName}] has a -UserName parameter that has an empty default value because no logged in users were detected when the toolkit was launched."
			}
			Else
			{
				Return
			}
		}
		
		## Confirm if the toolkit is running with administrator privileges
		If (($RunLevel -eq 'HighestAvailable') -and (-not $IsAdmin))
		{
			[int32]$executeProcessAsUserExitCode = 60003
			Write-Log -Message "The function [${CmdletName}] requires the toolkit to be running with Administrator privileges if the [-RunLevel] parameter is set to 'HighestAvailable'." -Severity 3 -Source ${CmdletName}
			If (-not $ContinueOnError)
			{
				Throw "The function [${CmdletName}] requires the toolkit to be running with Administrator privileges if the [-RunLevel] parameter is set to 'HighestAvailable'."
			}
			Else
			{
				Return
			}
		}
		
		## Build the scheduled task XML name
		[string]$schTaskName = "$appDeployToolkitName-ExecuteAsUser"
		
		##  Create the temporary App Deploy Toolkit files folder if it doesn't already exist
		If (-not (Test-Path -LiteralPath $dirAppDeployTemp -PathType 'Container'))
		{
			New-Item -Path $dirAppDeployTemp -ItemType 'Directory' -Force -ErrorAction 'Stop'
		}
		
		## If PowerShell.exe is being launched, then create a VBScript to launch PowerShell so that we can suppress the console window that flashes otherwise
		If (($Path -eq 'PowerShell.exe') -or ((Split-Path -Path $Path -Leaf) -eq 'PowerShell.exe'))
		{
			# Permit inclusion of double quotes in parameters
			If ($($Parameters.Substring($Parameters.Length - 1)) -eq '"')
			{
				[string]$executeProcessAsUserParametersVBS = 'chr(34) & ' + "`"$($Path)`"" + ' & chr(34) & ' + '" ' + ($Parameters -replace '"', "`" & chr(34) & `"" -replace ' & chr\(34\) & "$', '') + ' & chr(34)'
			}
			Else
			{
				[string]$executeProcessAsUserParametersVBS = 'chr(34) & ' + "`"$($Path)`"" + ' & chr(34) & ' + '" ' + ($Parameters -replace '"', "`" & chr(34) & `"" -replace ' & chr\(34\) & "$', '') + '"'
			}
			[string[]]$executeProcessAsUserScript = "strCommand = $executeProcessAsUserParametersVBS"
			$executeProcessAsUserScript += 'set oWShell = CreateObject("WScript.Shell")'
			$executeProcessAsUserScript += 'intReturn = oWShell.Run(strCommand, 0, true)'
			$executeProcessAsUserScript += 'WScript.Quit intReturn'
			$executeProcessAsUserScript | Out-File -FilePath "$dirAppDeployTemp\$($schTaskName).vbs" -Force -Encoding 'default' -ErrorAction 'SilentlyContinue'
			$Path = 'wscript.exe'
			$Parameters = "`"$dirAppDeployTemp\$($schTaskName).vbs`""
		}
		
		## Specify the scheduled task configuration in XML format
		[string]$xmlSchTask = @"
<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.2" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
  <RegistrationInfo />
  <Triggers />
  <Settings>
	<MultipleInstancesPolicy>StopExisting</MultipleInstancesPolicy>
	<DisallowStartIfOnBatteries>false</DisallowStartIfOnBatteries>
	<StopIfGoingOnBatteries>false</StopIfGoingOnBatteries>
	<AllowHardTerminate>true</AllowHardTerminate>
	<StartWhenAvailable>false</StartWhenAvailable>
	<RunOnlyIfNetworkAvailable>false</RunOnlyIfNetworkAvailable>
	<IdleSettings>
	  <StopOnIdleEnd>false</StopOnIdleEnd>
	  <RestartOnIdle>false</RestartOnIdle>
	</IdleSettings>
	<AllowStartOnDemand>true</AllowStartOnDemand>
	<Enabled>true</Enabled>
	<Hidden>false</Hidden>
	<RunOnlyIfIdle>false</RunOnlyIfIdle>
	<WakeToRun>false</WakeToRun>
	<ExecutionTimeLimit>PT72H</ExecutionTimeLimit>
	<Priority>7</Priority>
  </Settings>
  <Actions Context="Author">
	<Exec>
	  <Command>$Path</Command>
	  <Arguments>$Parameters</Arguments>
	</Exec>
  </Actions>
  <Principals>
	<Principal id="Author">
	  <UserId>$UserName</UserId>
	  <LogonType>InteractiveToken</LogonType>
	  <RunLevel>$RunLevel</RunLevel>
	</Principal>
  </Principals>
</Task>
"@
		## Export the XML to file
		Try
		{
			#  Specify the filename to export the XML to
			[string]$xmlSchTaskFilePath = "$dirAppDeployTemp\$schTaskName.xml"
			[string]$xmlSchTask | Out-File -FilePath $xmlSchTaskFilePath -Force -ErrorAction 'Stop'
		}
		Catch
		{
			[int32]$executeProcessAsUserExitCode = 60007
			Write-Log -Message "Failed to export the scheduled task XML file [$xmlSchTaskFilePath]. `n$(Resolve-Error)" -Severity 3 -Source ${CmdletName}
			If (-not $ContinueOnError)
			{
				Throw "Failed to export the scheduled task XML file [$xmlSchTaskFilePath]: $($_.Exception.Message)"
			}
			Else
			{
				Return
			}
		}
		
		## Create Scheduled Task to run the process with a logged-on user account
		If ($Parameters)
		{
			If ($SecureParameters)
			{
				Write-Log -Message "Create scheduled task to run the process [$Path] (Parameters Hidden) as the logged-on user [$userName]..." -Source ${CmdletName}
			}
			Else
			{
				Write-Log -Message "Create scheduled task to run the process [$Path $Parameters] as the logged-on user [$userName]..." -Source ${CmdletName}
			}
		}
		Else
		{
			Write-Log -Message "Create scheduled task to run the process [$Path] as the logged-on user [$userName]..." -Source ${CmdletName}
		}
		[psobject]$schTaskResult = Execute-Process -Path $exeSchTasks -Parameters "/create /f /tn $schTaskName /xml `"$xmlSchTaskFilePath`"" -WindowStyle 'Hidden' -CreateNoWindow -PassThru
		If ($schTaskResult.ExitCode -ne 0)
		{
			[int32]$executeProcessAsUserExitCode = $schTaskResult.ExitCode
			Write-Log -Message "Failed to create the scheduled task by importing the scheduled task XML file [$xmlSchTaskFilePath]." -Severity 3 -Source ${CmdletName}
			If (-not $ContinueOnError)
			{
				Throw "Failed to create the scheduled task by importing the scheduled task XML file [$xmlSchTaskFilePath]."
			}
			Else
			{
				Return
			}
		}
		
		## Trigger the Scheduled Task
		If ($Parameters)
		{
			If ($SecureParameters)
			{
				Write-Log -Message "Trigger execution of scheduled task with command [$Path] (Parameters Hidden) as the logged-on user [$userName]..." -Source ${CmdletName}
			}
			Else
			{
				Write-Log -Message "Trigger execution of scheduled task with command [$Path $Parameters] as the logged-on user [$userName]..." -Source ${CmdletName}
			}
		}
		Else
		{
			Write-Log -Message "Trigger execution of scheduled task with command [$Path] as the logged-on user [$userName]..." -Source ${CmdletName}
		}
		[psobject]$schTaskResult = Execute-Process -Path $exeSchTasks -Parameters "/run /i /tn $schTaskName" -WindowStyle 'Hidden' -CreateNoWindow -Passthru
		If ($schTaskResult.ExitCode -ne 0)
		{
			[int32]$executeProcessAsUserExitCode = $schTaskResult.ExitCode
			Write-Log -Message "Failed to trigger scheduled task [$schTaskName]." -Severity 3 -Source ${CmdletName}
			#  Delete Scheduled Task
			Write-Log -Message 'Delete the scheduled task which did not trigger.' -Source ${CmdletName}
			Execute-Process -Path $exeSchTasks -Parameters "/delete /tn $schTaskName /f" -WindowStyle 'Hidden' -CreateNoWindow -ContinueOnError $true
			If (-not $ContinueOnError)
			{
				Throw "Failed to trigger scheduled task [$schTaskName]."
			}
			Else
			{
				Return
			}
		}
		
		## Wait for the process launched by the scheduled task to complete execution
		If ($Wait)
		{
			Write-Log -Message "Waiting for the process launched by the scheduled task [$schTaskName] to complete execution (this may take some time)..." -Source ${CmdletName}
			Start-Sleep -Seconds 1
			#If on Windows Vista or higer, Windows Task Scheduler 2.0 is supported. 'Schedule.Service' ComObject output is UI language independent
			If (([version]$envOSVersion).Major -gt 5)
			{
				Try
				{
					[__comobject]$ScheduleService = New-Object -ComObject 'Schedule.Service' -ErrorAction Stop
					$ScheduleService.Connect()
					$RootFolder = $ScheduleService.GetFolder('\')
					$Task = $RootFolder.GetTask("$schTaskName")
					# Task State(Status) 4 = 'Running'
					While ($Task.State -eq 4)
					{
						Start-Sleep -Seconds 5
					}
					#  Get the exit code from the process launched by the scheduled task
					[int32]$executeProcessAsUserExitCode = $Task.LastTaskResult
				}
				Catch
				{
					Write-Log -Message "Failed to retrieve information from Task Scheduler. `n$(Resolve-Error)" -Severity 3 -Source ${CmdletName}
				}
				Finally
				{
					Try { $null = [Runtime.Interopservices.Marshal]::ReleaseComObject($ScheduleService) }
					Catch { }
				}
			}
			#Windows Task Scheduler 1.0
			Else
			{
				While ((($exeSchTasksResult = & $exeSchTasks /query /TN $schTaskName /V /FO CSV) | ConvertFrom-CSV | Select-Object -ExpandProperty 'Status' | Select-Object -First 1) -eq 'Running')
				{
					Start-Sleep -Seconds 5
				}
				#  Get the exit code from the process launched by the scheduled task
				[int32]$executeProcessAsUserExitCode = ($exeSchTasksResult = & $exeSchTasks /query /TN $schTaskName /V /FO CSV) | ConvertFrom-CSV | Select-Object -ExpandProperty 'Last Result' | Select-Object -First 1
			}
			Write-Log -Message "Exit code from process launched by scheduled task [$executeProcessAsUserExitCode]." -Source ${CmdletName}
		}
		Else
		{
			Start-Sleep -Seconds 1
		}
		
		## Delete scheduled task
		Try
		{
			Write-Log -Message "Delete scheduled task [$schTaskName]." -Source ${CmdletName}
			Execute-Process -Path $exeSchTasks -Parameters "/delete /tn $schTaskName /f" -WindowStyle 'Hidden' -CreateNoWindow -ErrorAction 'Stop'
		}
		Catch
		{
			Write-Log -Message "Failed to delete scheduled task [$schTaskName]. `n$(Resolve-Error)" -Severity 3 -Source ${CmdletName}
		}
	}
	End
	{
		If ($PassThru) { Write-Output -InputObject $executeProcessAsUserExitCode }
		
		Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -Footer
	}
}
#endregion

#region Function Invoke-HKCURegistrySettingsForAllUsers
Function Invoke-HKCURegistrySettingsForAllUsers
{
<#
.SYNOPSIS
	Set current user registry settings for all current users and any new users in the future.
.DESCRIPTION
	Set HKCU registry settings for all current and future users by loading their NTUSER.dat registry hive file, and making the modifications.
	This function will modify HKCU settings for all users even when executed under the SYSTEM account.
	To ensure new users in the future get the registry edits, the Default User registry hive used to provision the registry for new users is modified.
	This function can be used as an alternative to using ActiveSetup for registry settings.
	The advantage of using this function over ActiveSetup is that a user does not have to log off and log back on before the changes take effect.
.PARAMETER RegistrySettings
	Script block which contains HKCU registry settings which should be modified for all users on the system. Must specify the -SID parameter for all HKCU settings.
.PARAMETER UserProfiles
	Specify the user profiles to modify HKCU registry settings for. Default is all user profiles except for system profiles.
.EXAMPLE
	[scriptblock]$HKCURegistrySettings = {
		Set-RegistryKey -Key 'HKCU\Software\Microsoft\Office\14.0\Common' -Name 'qmenable' -Value 0 -Type DWord -SID $UserProfile.SID
		Set-RegistryKey -Key 'HKCU\Software\Microsoft\Office\14.0\Common' -Name 'updatereliabilitydata' -Value 1 -Type DWord -SID $UserProfile.SID
	}
	Invoke-HKCURegistrySettingsForAllUsers -RegistrySettings $HKCURegistrySettings
.NOTES
.LINK
	http://psappdeploytoolkit.com
#>
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $true)]
		[ValidateNotNullorEmpty()]
		[scriptblock]$RegistrySettings,
		[Parameter(Mandatory = $false)]
		[ValidateNotNullorEmpty()]
		[psobject[]]$UserProfiles = (Get-UserProfiles)
	)
	
	Begin
	{
		## Get the name of this function and write header
		[string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
		Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -CmdletBoundParameters $PSBoundParameters -Header
	}
	Process
	{
		ForEach ($UserProfile in $UserProfiles)
		{
			Try
			{
				#  Set the path to the user's registry hive when it is loaded
				[string]$UserRegistryPath = "Registry::HKEY_USERS\$($UserProfile.SID)"
				
				#  Set the path to the user's registry hive file
				[string]$UserRegistryHiveFile = Join-Path -Path $UserProfile.ProfilePath -ChildPath 'NTUSER.DAT'
				
				#  Load the User profile registry hive if it is not already loaded because the User is logged in
				[boolean]$ManuallyLoadedRegHive = $false
				If (-not (Test-Path -LiteralPath $UserRegistryPath))
				{
					#  Load the User registry hive if the registry hive file exists
					If (Test-Path -LiteralPath $UserRegistryHiveFile -PathType 'Leaf')
					{
						Write-Log -Message "Load the User [$($UserProfile.NTAccount)] registry hive in path [HKEY_USERS\$($UserProfile.SID)]." -Source ${CmdletName}
						[string]$HiveLoadResult = & reg.exe load "`"HKEY_USERS\$($UserProfile.SID)`"" "`"$UserRegistryHiveFile`""
						
						If ($global:LastExitCode -ne 0)
						{
							Throw "Failed to load the registry hive for User [$($UserProfile.NTAccount)] with SID [$($UserProfile.SID)]. Failure message [$HiveLoadResult]. Continue..."
						}
						
						[boolean]$ManuallyLoadedRegHive = $true
					}
					Else
					{
						Throw "Failed to find the registry hive file [$UserRegistryHiveFile] for User [$($UserProfile.NTAccount)] with SID [$($UserProfile.SID)]. Continue..."
					}
				}
				Else
				{
					Write-Log -Message "The User [$($UserProfile.NTAccount)] registry hive is already loaded in path [HKEY_USERS\$($UserProfile.SID)]." -Source ${CmdletName}
				}
				
				## Execute ScriptBlock which contains code to manipulate HKCU registry.
				#  Make sure read/write calls to the HKCU registry hive specify the -SID parameter or settings will not be changed for all users.
				#  Example: Set-RegistryKey -Key 'HKCU\Software\Microsoft\Office\14.0\Common' -Name 'qmenable' -Value 0 -Type DWord -SID $UserProfile.SID
				Write-Log -Message 'Execute ScriptBlock to modify HKCU registry settings for all users.' -Source ${CmdletName}
				& $RegistrySettings
			}
			Catch
			{
				Write-Log -Message "Failed to modify the registry hive for User [$($UserProfile.NTAccount)] with SID [$($UserProfile.SID)] `n$(Resolve-Error)" -Severity 3 -Source ${CmdletName}
			}
			Finally
			{
				If ($ManuallyLoadedRegHive)
				{
					Try
					{
						Write-Log -Message "Unload the User [$($UserProfile.NTAccount)] registry hive in path [HKEY_USERS\$($UserProfile.SID)]." -Source ${CmdletName}
						[string]$HiveLoadResult = & reg.exe unload "`"HKEY_USERS\$($UserProfile.SID)`""
						
						If ($global:LastExitCode -ne 0)
						{
							Write-Log -Message "REG.exe failed to unload the registry hive and exited with exit code [$($global:LastExitCode)]. Performing manual garbage collection to ensure successful unloading of registry hive." -Severity 2 -Source ${CmdletName}
							[GC]::Collect()
							[GC]::WaitForPendingFinalizers()
							Start-Sleep -Seconds 5
							
							Write-Log -Message "Unload the User [$($UserProfile.NTAccount)] registry hive in path [HKEY_USERS\$($UserProfile.SID)]." -Source ${CmdletName}
							[string]$HiveLoadResult = & reg.exe unload "`"HKEY_USERS\$($UserProfile.SID)`""
							If ($global:LastExitCode -ne 0) { Throw "REG.exe failed with exit code [$($global:LastExitCode)] and result [$HiveLoadResult]." }
						}
					}
					Catch
					{
						Write-Log -Message "Failed to unload the registry hive for User [$($UserProfile.NTAccount)] with SID [$($UserProfile.SID)]. `n$(Resolve-Error)" -Severity 3 -Source ${CmdletName}
					}
				}
			}
		}
	}
	End
	{
		Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -Footer
	}
}
#endregion

#region Function Update-SessionEnvironmentVariables
Function Update-SessionEnvironmentVariables
{
<#
.SYNOPSIS
	Updates the environment variables for the current PowerShell session with any environment variable changes that may have occurred during script execution.
.DESCRIPTION
	Environment variable changes that take place during script execution are not visible to the current PowerShell session.
	Use this function to refresh the current PowerShell session with all environment variable settings.
.PARAMETER LoadLoggedOnUserEnvironmentVariables
	If script is running in SYSTEM context, this option allows loading environment variables from the active console user. If no console user exists but users are logged in, such as on terminal servers, then the first logged-in non-console user.
.PARAMETER ContinueOnError
	Continue if an error is encountered. Default is: $true.
.EXAMPLE
	Update-SessionEnvironmentVariables
.NOTES
.LINK
	http://psappdeploytoolkit.com
#>
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $false)]
		[ValidateNotNullOrEmpty()]
		[switch]$LoadLoggedOnUserEnvironmentVariables = $false,
		[Parameter(Mandatory = $false)]
		[ValidateNotNullOrEmpty()]
		[boolean]$ContinueOnError = $true
	)
	
	Begin
	{
		## Get the name of this function and write header
		[string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
		Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -CmdletBoundParameters $PSBoundParameters -Header
		
		[scriptblock]$GetEnvironmentVar = {
			Param (
				$Key,
				$Scope
			)
			[Environment]::GetEnvironmentVariable($Key, $Scope)
		}
	}
	Process
	{
		Try
		{
			Write-Log -Message 'Refresh the environment variables for this PowerShell session.' -Source ${CmdletName}
			
			If ($LoadLoggedOnUserEnvironmentVariables -and $RunAsActiveUser)
			{
				[string]$CurrentUserEnvironmentSID = $RunAsActiveUser.SID
			}
			Else
			{
				[string]$CurrentUserEnvironmentSID = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
			}
			[string]$MachineEnvironmentVars = 'Registry::HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Session Manager\Environment'
			[string]$UserEnvironmentVars = "Registry::HKEY_USERS\$CurrentUserEnvironmentSID\Environment"
			
			## Update all session environment variables. Ordering is important here: $UserEnvironmentVars comes second so that we can override $MachineEnvironmentVars.
			$MachineEnvironmentVars, $UserEnvironmentVars | Get-Item | Where-Object { $_ } | ForEach-Object { $envRegPath = $_.PSPath; $_ | Select-Object -ExpandProperty 'Property' | ForEach-Object { Set-Item -LiteralPath "env:$($_)" -Value (Get-ItemProperty -LiteralPath $envRegPath -Name $_).$_ } }
			
			## Set PATH environment variable separately because it is a combination of the user and machine environment variables
			[string[]]$PathFolders = 'Machine', 'User' | ForEach-Object { (& $GetEnvironmentVar -Key 'PATH' -Scope $_) } | Where-Object { $_ } | ForEach-Object { $_.Trim(';') } | ForEach-Object { $_.Split(';') } | ForEach-Object { $_.Trim() } | ForEach-Object { $_.Trim('"') } | Select-Object -Unique
			$env:PATH = $PathFolders -join ';'
		}
		Catch
		{
			Write-Log -Message "Failed to refresh the environment variables for this PowerShell session. `n$(Resolve-Error)" -Severity 3 -Source ${CmdletName}
			If (-not $ContinueOnError)
			{
				Throw "Failed to refresh the environment variables for this PowerShell session: $($_.Exception.Message)"
			}
		}
	}
	End
	{
		Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -Footer
	}
}
Set-Alias -Name 'Refresh-SessionEnvironmentVariables' -Value 'Update-SessionEnvironmentVariables' -Scope 'Script' -Force -ErrorAction 'SilentlyContinue'
#endregion

#region Function Test-Battery
Function Test-Battery
{
<#
.SYNOPSIS
	Tests whether the local machine is running on AC power or not.
.DESCRIPTION
	Tests whether the local machine is running on AC power and returns true/false. For detailed information, use -PassThru option.
.DEPENDENCIES
	
.PARAMETER PassThru
	Outputs a hashtable containing the following properties:
	IsLaptop, IsUsingACPower, ACPowerLineStatus, BatteryChargeStatus, BatteryLifePercent, BatteryLifeRemaining, BatteryFullLifetime
.EXAMPLE
	Test-Battery
.EXAMPLE
	(Test-Battery -PassThru).IsLaptop
	Determines if the current system is a laptop or not.
.NOTES
.LINK
	http://psappdeploytoolkit.com
#>
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $false)]
		[ValidateNotNullOrEmpty()]
		[switch]$PassThru = $false
	)
	
	Begin
	{
		## Get the name of this function and write header
		[string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
		Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -CmdletBoundParameters $PSBoundParameters -Header
		
		## PowerStatus class found in this assembly is more reliable than WMI in cases where the battery is failing.
		Add-Type -Assembly 'System.Windows.Forms' -ErrorAction 'SilentlyContinue'
		
		## Initialize a hashtable to store information about system type and power status
		[hashtable]$SystemTypePowerStatus = @{ }
	}
	Process
	{
		Write-Log -Message 'Check if system is using AC power or if it is running on battery...' -Source ${CmdletName}
		
		[Windows.Forms.PowerStatus]$PowerStatus = [Windows.Forms.SystemInformation]::PowerStatus
		
		## Get the system power status. Indicates whether the system is using AC power or if the status is unknown. Possible values:
		#	Offline : The system is not using AC power.
		#	Online  : The system is using AC power.
		#	Unknown : The power status of the system is unknown.
		[string]$PowerLineStatus = $PowerStatus.PowerLineStatus
		$SystemTypePowerStatus.Add('ACPowerLineStatus', $PowerStatus.PowerLineStatus)
		
		## Get the current battery charge status. Possible values: High, Low, Critical, Charging, NoSystemBattery, Unknown.
		[string]$BatteryChargeStatus = $PowerStatus.BatteryChargeStatus
		$SystemTypePowerStatus.Add('BatteryChargeStatus', $PowerStatus.BatteryChargeStatus)
		
		## Get the approximate amount, from 0.00 to 1.0, of full battery charge remaining.
		#  This property can report 1.0 when the battery is damaged and Windows can't detect a battery.
		#  Therefore, this property is only indicative of battery charge remaining if 'BatteryChargeStatus' property is not reporting 'NoSystemBattery' or 'Unknown'.
		[single]$BatteryLifePercent = $PowerStatus.BatteryLifePercent
		If (($BatteryChargeStatus -eq 'NoSystemBattery') -or ($BatteryChargeStatus -eq 'Unknown'))
		{
			[single]$BatteryLifePercent = 0.0
		}
		$SystemTypePowerStatus.Add('BatteryLifePercent', $PowerStatus.BatteryLifePercent)
		
		## The reported approximate number of seconds of battery life remaining. It will report -1 if the remaining life is unknown because the system is on AC power.
		[int32]$BatteryLifeRemaining = $PowerStatus.BatteryLifeRemaining
		$SystemTypePowerStatus.Add('BatteryLifeRemaining', $PowerStatus.BatteryLifeRemaining)
		
		## Get the manufacturer reported full charge lifetime of the primary battery power source in seconds.
		#  The reported number of seconds of battery life available when the battery is fully charged, or -1 if it is unknown.
		#  This will only be reported if the battery supports reporting this information. You will most likely get -1, indicating unknown.
		[int32]$BatteryFullLifetime = $PowerStatus.BatteryFullLifetime
		$SystemTypePowerStatus.Add('BatteryFullLifetime', $PowerStatus.BatteryFullLifetime)
		
		## Determine if the system is using AC power
		[boolean]$OnACPower = $false
		If ($PowerLineStatus -eq 'Online')
		{
			Write-Log -Message 'System is using AC power.' -Source ${CmdletName}
			$OnACPower = $true
		}
		ElseIf ($PowerLineStatus -eq 'Offline')
		{
			Write-Log -Message 'System is using battery power.' -Source ${CmdletName}
		}
		ElseIf ($PowerLineStatus -eq 'Unknown')
		{
			If (($BatteryChargeStatus -eq 'NoSystemBattery') -or ($BatteryChargeStatus -eq 'Unknown'))
			{
				Write-Log -Message "System power status is [$PowerLineStatus] and battery charge status is [$BatteryChargeStatus]. This is most likely due to a damaged battery so we will report system is using AC power." -Source ${CmdletName}
				$OnACPower = $true
			}
			Else
			{
				Write-Log -Message "System power status is [$PowerLineStatus] and battery charge status is [$BatteryChargeStatus]. Therefore, we will report system is using battery power." -Source ${CmdletName}
			}
		}
		$SystemTypePowerStatus.Add('IsUsingACPower', $OnACPower)
		
		## Determine if the system is a laptop
		[boolean]$IsLaptop = $false
		If (($BatteryChargeStatus -eq 'NoSystemBattery') -or ($BatteryChargeStatus -eq 'Unknown'))
		{
			$IsLaptop = $false
		}
		Else
		{
			$IsLaptop = $true
		}
		#  Chassis Types
		[int32[]]$ChassisTypes = Get-WmiObject -Class 'Win32_SystemEnclosure' | Where-Object { $_.ChassisTypes } | Select-Object -ExpandProperty 'ChassisTypes'
		Write-Log -Message "The following system chassis types were detected [$($ChassisTypes -join ',')]." -Source ${CmdletName}
		ForEach ($ChassisType in $ChassisTypes)
		{
			Switch ($ChassisType)
			{
				{ $_ -eq 9 -or $_ -eq 10 -or $_ -eq 14 } { $IsLaptop = $true } # 9=Laptop, 10=Notebook, 14=Sub Notebook
				{ $_ -eq 3 } { $IsLaptop = $false } # 3=Desktop
			}
		}
		#  Add IsLaptop property to hashtable
		$SystemTypePowerStatus.Add('IsLaptop', $IsLaptop)
		
		If ($PassThru)
		{
			Write-Output -InputObject $SystemTypePowerStatus
		}
		Else
		{
			Write-Output -InputObject $OnACPower
		}
	}
	End
	{
		Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -Footer
	}
}
#endregion

#region Function Set-ActiveSetup
Function Set-ActiveSetup
{
<#
.SYNOPSIS
	Creates an Active Setup entry in the registry to execute a file for each user upon login.
.DESCRIPTION
	Active Setup allows handling of per-user changes registry/file changes upon login.
	A registry key is created in the HKLM registry hive which gets replicated to the HKCU hive when a user logs in.
	If the "Version" value of the Active Setup entry in HKLM is higher than the version value in HKCU, the file referenced in "StubPath" is executed.
	This Function:
	- Creates the registry entries in HKLM:SOFTWARE\Microsoft\Active Setup\Installed Components\$installName.
	- Creates StubPath value depending on the file extension of the $StubExePath parameter.
	- Handles Version value with YYYYMMDDHHMMSS granularity to permit re-installs on the same day and still trigger Active Setup after Version increase.
	- Copies/overwrites the StubPath file to $StubExePath destination path if file exists in 'Files' subdirectory of script directory.
	- Executes the StubPath file for the current user as long as not in Session 0 (no need to logout/login to trigger Active Setup).
.PARAMETER StubExePath
	Full destination path to the file that will be executed for each user that logs in.
	If this file exists in the 'Files' subdirectory of the script directory, it will be copied to the destination path.
.PARAMETER Arguments
	Arguments to pass to the file being executed.
.PARAMETER Description
	Description for the Active Setup. Users will see "Setting up personalized settings for: $Description" at logon. Default is: $installName.
.PARAMETER Key
	Name of the registry key for the Active Setup entry. Default is: $installName.
.PARAMETER Version
	Optional. Specify version for Active setup entry. Active Setup is not triggered if Version value has more than 8 consecutive digits. Use commas to get around this limitation.
.PARAMETER Locale
	Optional. Arbitrary string used to specify the installation language of the file being executed. Not replicated to HKCU.
.PARAMETER PurgeActiveSetupKey
	Remove Active Setup entry from HKLM registry hive. Will also load each logon user's HKCU registry hive to remove Active Setup entry.
.PARAMETER DisableActiveSetup
	Disables the Active Setup entry so that the StubPath file will not be executed.
.PARAMETER ContinueOnError
	Continue if an error is encountered. Default is: $true.
.EXAMPLE
	Set-ActiveSetup -StubExePath 'C:\Users\Public\Company\ProgramUserConfig.vbs' -Arguments '/Silent' -Description 'Program User Config' -Key 'ProgramUserConfig' -Locale 'en'
.EXAMPLE
	Set-ActiveSetup -StubExePath "$envWinDir\regedit.exe" -Arguments "/S `"%SystemDrive%\Program Files (x86)\PS App Deploy\PSAppDeployHKCUSettings.reg`"" -Description 'PS App Deploy Config' -Key 'PS_App_Deploy_Config' -ContinueOnError $true
.EXAMPLE
	Set-ActiveSetup -Key 'ProgramUserConfig' -PurgeActiveSetupKey
	Deletes "ProgramUserConfig" active setup entry from all registry hives.
.NOTES
	Original code borrowed from: Denis St-Pierre (Ottawa, Canada), Todd MacNaught (Ottawa, Canada)
.LINK
	http://psappdeploytoolkit.com
#>
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $true, ParameterSetName = 'Create')]
		[ValidateNotNullorEmpty()]
		[string]$StubExePath,
		[Parameter(Mandatory = $false, ParameterSetName = 'Create')]
		[ValidateNotNullorEmpty()]
		[string]$Arguments,
		[Parameter(Mandatory = $false, ParameterSetName = 'Create')]
		[ValidateNotNullorEmpty()]
		[string]$Description = $installName,
		[Parameter(Mandatory = $false)]
		[ValidateNotNullorEmpty()]
		[string]$Key = $installName,
		[Parameter(Mandatory = $false, ParameterSetName = 'Create')]
		[ValidateNotNullorEmpty()]
		[string]$Version = ((Get-Date -Format 'yyMM,ddHH,mmss').ToString()),
		# Ex: 1405,1515,0522

		[Parameter(Mandatory = $false, ParameterSetName = 'Create')]
		[ValidateNotNullorEmpty()]
		[string]$Locale,
		[Parameter(Mandatory = $false, ParameterSetName = 'Create')]
		[ValidateNotNullorEmpty()]
		[switch]$DisableActiveSetup = $false,
		[Parameter(Mandatory = $true, ParameterSetName = 'Purge')]
		[switch]$PurgeActiveSetupKey,
		[Parameter(Mandatory = $false)]
		[ValidateNotNullorEmpty()]
		[boolean]$ContinueOnError = $true
	)
	
	Begin
	{
		## Get the name of this function and write header
		[string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
		Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -CmdletBoundParameters $PSBoundParameters -Header
	}
	Process
	{
		Try
		{
			[string]$ActiveSetupKey = "HKLM:SOFTWARE\Microsoft\Active Setup\Installed Components\$Key"
			[string]$HKCUActiveSetupKey = "HKCU:Software\Microsoft\Active Setup\Installed Components\$Key"
			
			## Delete Active Setup registry entry from the HKLM hive and for all logon user registry hives on the system
			If ($PurgeActiveSetupKey)
			{
				Write-Log -Message "Remove Active Setup entry [$ActiveSetupKey]." -Source ${CmdletName}
				Remove-RegistryKey -Key $ActiveSetupKey -Recurse
				
				Write-Log -Message "Remove Active Setup entry [$HKCUActiveSetupKey] for all log on user registry hives on the system." -Source ${CmdletName}
				[scriptblock]$RemoveHKCUActiveSetupKey = {
					If (Test-Path -Path $HKCUActiveSetupKey)
					{
						Remove-RegistryKey -Key $HKCUActiveSetupKey -SID $UserProfile.SID -Recurse
					}
				}
				Invoke-HKCURegistrySettingsForAllUsers -RegistrySettings $RemoveHKCUActiveSetupKey -UserProfiles (Get-UserProfiles -ExcludeDefaultUser)
				Return
			}
			
			## Verify a file with a supported file extension was specified in $StubExePath
			[string[]]$StubExePathFileExtensions = '.exe', '.vbs', '.cmd', '.ps1', '.js'
			[string]$StubExeExt = [IO.Path]::GetExtension($StubExePath)
			If ($StubExePathFileExtensions -notcontains $StubExeExt)
			{
				Throw "Unsupported Active Setup StubPath file extension [$StubExeExt]."
			}
			
			## Copy file to $StubExePath from the 'Files' subdirectory of the script directory (if it exists there)
			[string]$StubExePath = [Environment]::ExpandEnvironmentVariables($StubExePath)
			[string]$ActiveSetupFileName = [IO.Path]::GetFileName($StubExePath)
			[string]$StubExeFile = Join-Path -Path $dirFiles -ChildPath $ActiveSetupFileName
			If (Test-Path -LiteralPath $StubExeFile -PathType 'Leaf')
			{
				#  This will overwrite the StubPath file if $StubExePath already exists on target
				Copy-File -Path $StubExeFile -Destination $StubExePath -ContinueOnError $false
			}
			
			## Check if the $StubExePath file exists
			If (-not (Test-Path -LiteralPath $StubExePath -PathType 'Leaf')) { Throw "Active Setup StubPath file [$ActiveSetupFileName] is missing." }
			
			## Define Active Setup StubPath according to file extension of $StubExePath
			Switch ($StubExeExt)
			{
				'.exe' {
					[string]$CUStubExePath = $StubExePath
					[string]$CUArguments = $Arguments
					[string]$StubPath = "$CUStubExePath"
				}
				{ '.vbs', '.js' -contains $StubExeExt } {
					[string]$CUStubExePath = "$envWinDir\system32\cscript.exe"
					[string]$CUArguments = "//nologo `"$StubExePath`""
					[string]$StubPath = "$CUStubExePath $CUArguments"
				}
				'.cmd' {
					[string]$CUStubExePath = "$envWinDir\system32\CMD.exe"
					[string]$CUArguments = "/C `"$StubExePath`""
					[string]$StubPath = "$CUStubExePath $CUArguments"
				}
				'.ps1' {
					[string]$CUStubExePath = "$PSHOME\powershell.exe"
					[string]$CUArguments = "-ExecutionPolicy Bypass -NoProfile -NoLogo -WindowStyle Hidden -Command `"& { & `\`"$StubExePath`\`"}`""
					[string]$StubPath = "$CUStubExePath $CUArguments"
				}
			}
			If ($Arguments)
			{
				[string]$StubPath = "$StubPath $Arguments"
				If ($StubExeExt -ne '.exe') { [string]$CUArguments = "$CUArguments $Arguments" }
			}
			
			## Create the Active Setup entry in the registry
			[scriptblock]$SetActiveSetupRegKeys = {
				Param (
					[Parameter(Mandatory = $true)]
					[ValidateNotNullorEmpty()]
					[string]$ActiveSetupRegKey,
					[Parameter(Mandatory = $false)]
					[ValidateNotNullorEmpty()]
					[string]$SID
				)
				If ($SID)
				{
					Set-RegistryKey -Key $ActiveSetupRegKey -Name '(Default)' -Value $Description -SID $SID -ContinueOnError $false
					Set-RegistryKey -Key $ActiveSetupRegKey -Name 'StubPath' -Value $StubPath -Type 'String' -SID $SID -ContinueOnError $false
					Set-RegistryKey -Key $ActiveSetupRegKey -Name 'Version' -Value $Version -SID $SID -ContinueOnError $false
					If ($Locale) { Set-RegistryKey -Key $ActiveSetupRegKey -Name 'Locale' -Value $Locale -SID $SID -ContinueOnError $false }
					If ($DisableActiveSetup)
					{
						Set-RegistryKey -Key $ActiveSetupRegKey -Name 'IsInstalled' -Value 0 -Type 'DWord' -SID $SID -ContinueOnError $false
					}
					Else
					{
						Set-RegistryKey -Key $ActiveSetupRegKey -Name 'IsInstalled' -Value 1 -Type 'DWord' -SID $SID -ContinueOnError $false
					}
				}
				Else
				{
					Set-RegistryKey -Key $ActiveSetupRegKey -Name '(Default)' -Value $Description -ContinueOnError $false
					Set-RegistryKey -Key $ActiveSetupRegKey -Name 'StubPath' -Value $StubPath -Type 'String' -ContinueOnError $false
					Set-RegistryKey -Key $ActiveSetupRegKey -Name 'Version' -Value $Version -ContinueOnError $false
					If ($Locale) { Set-RegistryKey -Key $ActiveSetupRegKey -Name 'Locale' -Value $Locale -ContinueOnError $false }
					If ($DisableActiveSetup)
					{
						Set-RegistryKey -Key $ActiveSetupRegKey -Name 'IsInstalled' -Value 0 -Type 'DWord' -ContinueOnError $false
					}
					Else
					{
						Set-RegistryKey -Key $ActiveSetupRegKey -Name 'IsInstalled' -Value 1 -Type 'DWord' -ContinueOnError $false
					}
				}
				
			}
			& $SetActiveSetupRegKeys -ActiveSetupRegKey $ActiveSetupKey
			
			## Execute the StubPath file for the current user as long as not in Session 0
			If ($SessionZero)
			{
				If ($RunAsActiveUser)
				{
					Write-Log -Message "Session 0 detected: Execute Active Setup StubPath file for currently logged in user [$($RunAsActiveUser.NTAccount)]." -Source ${CmdletName}
					If ($CUArguments)
					{
						Execute-ProcessAsUser -Path $CUStubExePath -Parameters $CUArguments -Wait -ContinueOnError $true
					}
					Else
					{
						Execute-ProcessAsUser -Path $CUStubExePath -Wait -ContinueOnError $true
					}
					& $SetActiveSetupRegKeys -ActiveSetupRegKey $HKCUActiveSetupKey -SID $RunAsActiveUser.SID
				}
				Else
				{
					Write-Log -Message 'Session 0 detected: No logged in users detected. Active Setup StubPath file will execute when users first log into their account.' -Source ${CmdletName}
				}
			}
			Else
			{
				Write-Log -Message 'Execute Active Setup StubPath file for the current user.' -Source ${CmdletName}
				If ($CUArguments)
				{
					$ExecuteResults = Execute-Process -FilePath $CUStubExePath -Parameters $CUArguments -PassThru
				}
				Else
				{
					$ExecuteResults = Execute-Process -FilePath $CUStubExePath -PassThru
				}
				& $SetActiveSetupRegKeys -ActiveSetupRegKey $HKCUActiveSetupKey
			}
		}
		Catch
		{
			Write-Log -Message "Failed to set Active Setup registry entry. `n$(Resolve-Error)" -Severity 3 -Source ${CmdletName}
			If (-not $ContinueOnError)
			{
				Throw "Failed to set Active Setup registry entry: $($_.Exception.Message)"
			}
		}
	}
	End
	{
		Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -Footer
	}
}
#endregion

#region Function Test-ServiceExists
Function Test-ServiceExists
{
<#
.SYNOPSIS
	Check to see if a service exists.
.DESCRIPTION
	Check to see if a service exists (using WMI method because Get-Service will generate ErrorRecord if service doesn't exist).
.PARAMETER Name
	Specify the name of the service.
	Note: Service name can be found by executing "Get-Service | Format-Table -AutoSize -Wrap" or by using the properties screen of a service in services.msc.
.PARAMETER ComputerName
	Specify the name of the computer. Default is: the local computer.
.PARAMETER PassThru
	Return the WMI service object.
.PARAMETER ContinueOnError
	Continue if an error is encountered. Default is: $true.
.EXAMPLE
	Test-ServiceExists -Name 'wuauserv'
.EXAMPLE
	Test-ServiceExists -Name 'testservice' -PassThru | Where-Object { $_ } | ForEach-Object { $_.Delete() }
	Check if a service exists and then delete it by using the -PassThru parameter.
.NOTES
.LINK
	http://psappdeploytoolkit.com
#>
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
		[string]$Name,
		[Parameter(Mandatory = $false)]
		[ValidateNotNullOrEmpty()]
		[string]$ComputerName = $env:ComputerName,
		[Parameter(Mandatory = $false)]
		[ValidateNotNullOrEmpty()]
		[switch]$PassThru,
		[Parameter(Mandatory = $false)]
		[ValidateNotNullOrEmpty()]
		[boolean]$ContinueOnError = $true
	)
	Begin
	{
		[string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
		Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -CmdletBoundParameters $PSBoundParameters -Header
	}
	Process
	{
		Try
		{
			$ServiceObject = Get-WmiObject -ComputerName $ComputerName -Class 'Win32_Service' -Filter "Name='$Name'" -ErrorAction 'Stop'
			# If nothing is returned from Win32_Service, check Win32_BaseService
			If (-not ($ServiceObject))
			{
				$ServiceObject = Get-WmiObject -ComputerName $ComputerName -Class 'Win32_BaseService' -Filter "Name='$Name'" -ErrorAction 'Stop'
			}
			
			If ($ServiceObject)
			{
				Write-Log -Message "Service [$Name] exists." -Source ${CmdletName}
				If ($PassThru) { Write-Output -InputObject $ServiceObject }
				Else { Write-Output -InputObject $true }
			}
			Else
			{
				Write-Log -Message "Service [$Name] does not exist." -Source ${CmdletName}
				If ($PassThru) { Write-Output -InputObject $ServiceObject }
				Else { Write-Output -InputObject $false }
			}
		}
		Catch
		{
			Write-Log -Message "Failed check to see if service [$Name] exists." -Severity 3 -Source ${CmdletName}
			If (-not $ContinueOnError)
			{
				Throw "Failed check to see if service [$Name] exists: $($_.Exception.Message)"
			}
		}
	}
	End
	{
		Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -Footer
	}
}
#endregion

#region Function Get-DeferHistory
Function Get-DeferHistory
{
<#
.SYNOPSIS
	Get the history of deferrals from the registry for the current application, if it exists.
.DESCRIPTION
	Get the history of deferrals from the registry for the current application, if it exists.
.DEPENDENCIES
	Get-RegistryKey
.EXAMPLE
	Get-DeferHistory
.NOTES
	This is an internal script function and should typically not be called directly.
.LINK
	http://psappdeploytoolkit.com
#>
	[CmdletBinding()]
	Param (
	)
	
	Begin
	{
		## Get the name of this function and write header
		[string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
		Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -CmdletBoundParameters $PSBoundParameters -Header
	}
	Process
	{
		Write-Log -Message 'Get deferral history...' -Source ${CmdletName}
		Get-RegistryKey -Key $regKeyDeferHistory -ContinueOnError $true
	}
	End
	{
		Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -Footer
	}
}
#endregion

#region Function Set-DeferHistory
Function Set-DeferHistory
{
<#
.SYNOPSIS
	Set the history of deferrals in the registry for the current application.
.DESCRIPTION
	Set the history of deferrals in the registry for the current application.
.DEPENDENCIES
	
.EXAMPLE
	Set-DeferHistory
.NOTES
	This is an internal script function and should typically not be called directly.
.LINK
	http://psappdeploytoolkit.com
#>
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $false)]
		[string]$deferTimesRemaining,
		[Parameter(Mandatory = $false)]
		[string]$deferDeadline
	)
	
	Begin
	{
		## Get the name of this function and write header
		[string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
		Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -CmdletBoundParameters $PSBoundParameters -Header
	}
	Process
	{
		If ($deferTimesRemaining -and ($deferTimesRemaining -ge 0))
		{
			Write-Log -Message "Set deferral history: [DeferTimesRemaining = $deferTimesRemaining]." -Source ${CmdletName}
			Set-RegistryKey -Key $regKeyDeferHistory -Name 'DeferTimesRemaining' -Value $deferTimesRemaining -ContinueOnError $true
		}
		If ($deferDeadline)
		{
			Write-Log -Message "Set deferral history: [DeferDeadline = $deferDeadline]." -Source ${CmdletName}
			Set-RegistryKey -Key $regKeyDeferHistory -Name 'DeferDeadline' -Value $deferDeadline -ContinueOnError $true
		}
	}
	End
	{
		Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -Footer
	}
}
#endregion

#region Function Stop-ServiceAndDependencies
Function Stop-ServiceAndDependencies
{
<#
.SYNOPSIS
	Stop Windows service and its dependencies.
.DESCRIPTION
	Stop Windows service and its dependencies.
.PARAMETER Name
	Specify the name of the service.
.PARAMETER ComputerName
	Specify the name of the computer. Default is: the local computer.
.PARAMETER SkipServiceExistsTest
	Choose to skip the test to check whether or not the service exists if it was already done outside of this function.
.PARAMETER SkipDependentServices
	Choose to skip checking for and stopping dependent services. Default is: $false.
.PARAMETER PendingStatusWait
	The amount of time to wait for a service to get out of a pending state before continuing. Default is 60 seconds.
.PARAMETER PassThru
	Return the System.ServiceProcess.ServiceController service object.
.PARAMETER ContinueOnError
	Continue if an error is encountered. Default is: $true.
.EXAMPLE
	Stop-ServiceAndDependencies -Name 'wuauserv'
.NOTES
.LINK
	http://psappdeploytoolkit.com
#>
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
		[string]$Name,
		[Parameter(Mandatory = $false)]
		[ValidateNotNullOrEmpty()]
		[string]$ComputerName = $env:ComputerName,
		[Parameter(Mandatory = $false)]
		[ValidateNotNullOrEmpty()]
		[switch]$SkipServiceExistsTest,
		[Parameter(Mandatory = $false)]
		[ValidateNotNullOrEmpty()]
		[switch]$SkipDependentServices,
		[Parameter(Mandatory = $false)]
		[ValidateNotNullOrEmpty()]
		[timespan]$PendingStatusWait = (New-TimeSpan -Seconds 60),
		[Parameter(Mandatory = $false)]
		[ValidateNotNullOrEmpty()]
		[switch]$PassThru,
		[Parameter(Mandatory = $false)]
		[ValidateNotNullOrEmpty()]
		[boolean]$ContinueOnError = $true
	)
	Begin
	{
		[string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
		Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -CmdletBoundParameters $PSBoundParameters -Header
	}
	Process
	{
		Try
		{
			## Check to see if the service exists
			If ((-not $SkipServiceExistsTest) -and (-not (Test-ServiceExists -ComputerName $ComputerName -Name $Name -ContinueOnError $false)))
			{
				Write-Log -Message "Service [$Name] does not exist." -Source ${CmdletName} -Severity 2
				Throw "Service [$Name] does not exist."
			}
			
			## Get the service object
			Write-Log -Message "Get the service object for service [$Name]." -Source ${CmdletName}
			[ServiceProcess.ServiceController]$Service = Get-Service -ComputerName $ComputerName -Name $Name -ErrorAction 'Stop'
			## Wait up to 60 seconds if service is in a pending state
			[string[]]$PendingStatus = 'ContinuePending', 'PausePending', 'StartPending', 'StopPending'
			If ($PendingStatus -contains $Service.Status)
			{
				Switch ($Service.Status)
				{
					'ContinuePending' { $DesiredStatus = 'Running' }
					'PausePending' { $DesiredStatus = 'Paused' }
					'StartPending' { $DesiredStatus = 'Running' }
					'StopPending' { $DesiredStatus = 'Stopped' }
				}
				Write-Log -Message "Waiting for up to [$($PendingStatusWait.TotalSeconds)] seconds to allow service pending status [$($Service.Status)] to reach desired status [$DesiredStatus]." -Source ${CmdletName}
				$Service.WaitForStatus([ServiceProcess.ServiceControllerStatus]$DesiredStatus, $PendingStatusWait)
				$Service.Refresh()
			}
			## Discover if the service is currently running
			Write-Log -Message "Service [$($Service.ServiceName)] with display name [$($Service.DisplayName)] has a status of [$($Service.Status)]." -Source ${CmdletName}
			If ($Service.Status -ne 'Stopped')
			{
				#  Discover all dependent services that are running and stop them
				If (-not $SkipDependentServices)
				{
					Write-Log -Message "Discover all dependent service(s) for service [$Name] which are not 'Stopped'." -Source ${CmdletName}
					[ServiceProcess.ServiceController[]]$DependentServices = Get-Service -ComputerName $ComputerName -Name $Service.ServiceName -DependentServices -ErrorAction 'Stop' | Where-Object { $_.Status -ne 'Stopped' }
					If ($DependentServices)
					{
						ForEach ($DependentService in $DependentServices)
						{
							Write-Log -Message "Stop dependent service [$($DependentService.ServiceName)] with display name [$($DependentService.DisplayName)] and a status of [$($DependentService.Status)]." -Source ${CmdletName}
							Try
							{
								Stop-Service -InputObject (Get-Service -ComputerName $ComputerName -Name $DependentService.ServiceName -ErrorAction 'Stop') -Force -WarningAction 'SilentlyContinue' -ErrorAction 'Stop'
							}
							Catch
							{
								Write-Log -Message "Failed to start dependent service [$($DependentService.ServiceName)] with display name [$($DependentService.DisplayName)] and a status of [$($DependentService.Status)]. Continue..." -Severity 2 -Source ${CmdletName}
								Continue
							}
						}
					}
					Else
					{
						Write-Log -Message "Dependent service(s) were not discovered for service [$Name]." -Source ${CmdletName}
					}
				}
				#  Stop the parent service
				Write-Log -Message "Stop parent service [$($Service.ServiceName)] with display name [$($Service.DisplayName)]." -Source ${CmdletName}
				[ServiceProcess.ServiceController]$Service = Stop-Service -InputObject (Get-Service -ComputerName $ComputerName -Name $Service.ServiceName -ErrorAction 'Stop') -Force -PassThru -WarningAction 'SilentlyContinue' -ErrorAction 'Stop'
			}
		}
		Catch
		{
			Write-Log -Message "Failed to stop the service [$Name]. `n$(Resolve-Error)" -Source ${CmdletName} -Severity 3
			If (-not $ContinueOnError)
			{
				Throw "Failed to stop the service [$Name]: $($_.Exception.Message)"
			}
		}
		Finally
		{
			#  Return the service object if option selected
			If ($PassThru -and $Service) { Write-Output -InputObject $Service }
		}
	}
	End
	{
		Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -Footer
	}
}
#endregion

#region Function Start-ServiceAndDependencies
Function Start-ServiceAndDependencies
{
<#
.SYNOPSIS
	Start Windows service and its dependencies.
.DESCRIPTION
	Start Windows service and its dependencies.
.PARAMETER Name
	Specify the name of the service.
.PARAMETER ComputerName
	Specify the name of the computer. Default is: the local computer.
.PARAMETER SkipServiceExistsTest
	Choose to skip the test to check whether or not the service exists if it was already done outside of this function.
.PARAMETER SkipDependentServices
	Choose to skip checking for and starting dependent services. Default is: $false.
.PARAMETER PendingStatusWait
	The amount of time to wait for a service to get out of a pending state before continuing. Default is 60 seconds.
.PARAMETER PassThru
	Return the System.ServiceProcess.ServiceController service object.
.PARAMETER ContinueOnError
	Continue if an error is encountered. Default is: $true.
.EXAMPLE
	Start-ServiceAndDependencies -Name 'wuauserv'
.NOTES
.LINK
	http://psappdeploytoolkit.com
#>
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
		[string]$Name,
		[Parameter(Mandatory = $false)]
		[ValidateNotNullOrEmpty()]
		[string]$ComputerName = $env:ComputerName,
		[Parameter(Mandatory = $false)]
		[ValidateNotNullOrEmpty()]
		[switch]$SkipServiceExistsTest,
		[Parameter(Mandatory = $false)]
		[ValidateNotNullOrEmpty()]
		[switch]$SkipDependentServices,
		[Parameter(Mandatory = $false)]
		[ValidateNotNullOrEmpty()]
		[timespan]$PendingStatusWait = (New-TimeSpan -Seconds 60),
		[Parameter(Mandatory = $false)]
		[ValidateNotNullOrEmpty()]
		[switch]$PassThru,
		[Parameter(Mandatory = $false)]
		[ValidateNotNullOrEmpty()]
		[boolean]$ContinueOnError = $true
	)
	Begin
	{
		[string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
		Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -CmdletBoundParameters $PSBoundParameters -Header
	}
	Process
	{
		Try
		{
			## Check to see if the service exists
			If ((-not $SkipServiceExistsTest) -and (-not (Test-ServiceExists -ComputerName $ComputerName -Name $Name -ContinueOnError $false)))
			{
				Write-Log -Message "Service [$Name] does not exist." -Source ${CmdletName} -Severity 2
				Throw "Service [$Name] does not exist."
			}
			
			## Get the service object
			Write-Log -Message "Get the service object for service [$Name]." -Source ${CmdletName}
			[ServiceProcess.ServiceController]$Service = Get-Service -ComputerName $ComputerName -Name $Name -ErrorAction 'Stop'
			## Wait up to 60 seconds if service is in a pending state
			[string[]]$PendingStatus = 'ContinuePending', 'PausePending', 'StartPending', 'StopPending'
			If ($PendingStatus -contains $Service.Status)
			{
				Switch ($Service.Status)
				{
					'ContinuePending' { $DesiredStatus = 'Running' }
					'PausePending' { $DesiredStatus = 'Paused' }
					'StartPending' { $DesiredStatus = 'Running' }
					'StopPending' { $DesiredStatus = 'Stopped' }
				}
				Write-Log -Message "Waiting for up to [$($PendingStatusWait.TotalSeconds)] seconds to allow service pending status [$($Service.Status)] to reach desired status [$DesiredStatus]." -Source ${CmdletName}
				$Service.WaitForStatus([ServiceProcess.ServiceControllerStatus]$DesiredStatus, $PendingStatusWait)
				$Service.Refresh()
			}
			## Discover if the service is currently stopped
			Write-Log -Message "Service [$($Service.ServiceName)] with display name [$($Service.DisplayName)] has a status of [$($Service.Status)]." -Source ${CmdletName}
			If ($Service.Status -ne 'Running')
			{
				#  Start the parent service
				Write-Log -Message "Start parent service [$($Service.ServiceName)] with display name [$($Service.DisplayName)]." -Source ${CmdletName}
				[ServiceProcess.ServiceController]$Service = Start-Service -InputObject (Get-Service -ComputerName $ComputerName -Name $Service.ServiceName -ErrorAction 'Stop') -PassThru -WarningAction 'SilentlyContinue' -ErrorAction 'Stop'
				
				#  Discover all dependent services that are stopped and start them
				If (-not $SkipDependentServices)
				{
					Write-Log -Message "Discover all dependent service(s) for service [$Name] which are not 'Running'." -Source ${CmdletName}
					[ServiceProcess.ServiceController[]]$DependentServices = Get-Service -ComputerName $ComputerName -Name $Service.ServiceName -DependentServices -ErrorAction 'Stop' | Where-Object { $_.Status -ne 'Running' }
					If ($DependentServices)
					{
						ForEach ($DependentService in $DependentServices)
						{
							Write-Log -Message "Start dependent service [$($DependentService.ServiceName)] with display name [$($DependentService.DisplayName)] and a status of [$($DependentService.Status)]." -Source ${CmdletName}
							Try
							{
								Start-Service -InputObject (Get-Service -ComputerName $ComputerName -Name $DependentService.ServiceName -ErrorAction 'Stop') -WarningAction 'SilentlyContinue' -ErrorAction 'Stop'
							}
							Catch
							{
								Write-Log -Message "Failed to start dependent service [$($DependentService.ServiceName)] with display name [$($DependentService.DisplayName)] and a status of [$($DependentService.Status)]. Continue..." -Severity 2 -Source ${CmdletName}
								Continue
							}
						}
					}
					Else
					{
						Write-Log -Message "Dependent service(s) were not discovered for service [$Name]." -Source ${CmdletName}
					}
				}
			}
		}
		Catch
		{
			Write-Log -Message "Failed to start the service [$Name]. `n$(Resolve-Error)" -Source ${CmdletName} -Severity 3
			If (-not $ContinueOnError)
			{
				Throw "Failed to start the service [$Name]: $($_.Exception.Message)"
			}
		}
		Finally
		{
			#  Return the service object if option selected
			If ($PassThru -and $Service) { Write-Output -InputObject $Service }
		}
	}
	End
	{
		Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -Footer
	}
}
#endregion

#region Function Get-ServiceStartMode
Function Get-ServiceStartMode
{
<#
.SYNOPSIS
	Get the service startup mode.
.DESCRIPTION
	Get the service startup mode.
.PARAMETER Name
	Specify the name of the service.
.PARAMETER ComputerName
	Specify the name of the computer. Default is: the local computer.
.PARAMETER ContinueOnError
	Continue if an error is encountered. Default is: $true.
.EXAMPLE
	Get-ServiceStartMode -Name 'wuauserv'
.NOTES
.LINK
	http://psappdeploytoolkit.com
#>
	[CmdLetBinding()]
	Param (
		[Parameter(Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
		[string]$Name,
		[Parameter(Mandatory = $false)]
		[ValidateNotNullOrEmpty()]
		[string]$ComputerName = $env:ComputerName,
		[Parameter(Mandatory = $false)]
		[ValidateNotNullOrEmpty()]
		[boolean]$ContinueOnError = $true
	)
	Begin
	{
		[string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
		Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -CmdletBoundParameters $PSBoundParameters -Header
	}
	Process
	{
		Try
		{
			Write-Log -Message "Get the service [$Name] startup mode." -Source ${CmdletName}
			[string]$ServiceStartMode = (Get-WmiObject -ComputerName $ComputerName -Class 'Win32_Service' -Filter "Name='$Name'" -Property 'StartMode' -ErrorAction 'Stop').StartMode
			## If service start mode is set to 'Auto', change value to 'Automatic' to be consistent with 'Set-ServiceStartMode' function
			If ($ServiceStartMode -eq 'Auto') { $ServiceStartMode = 'Automatic' }
			
			## If on Windows Vista or higher, check to see if service is set to Automatic (Delayed Start)
			If (($ServiceStartMode -eq 'Automatic') -and (([version]$envOSVersion).Major -gt 5))
			{
				Try
				{
					[string]$ServiceRegistryPath = "HKLM:SYSTEM\CurrentControlSet\Services\$Name"
					[int32]$DelayedAutoStart = Get-ItemProperty -LiteralPath $ServiceRegistryPath -ErrorAction 'Stop' | Select-Object -ExpandProperty 'DelayedAutoStart' -ErrorAction 'Stop'
					If ($DelayedAutoStart -eq 1) { $ServiceStartMode = 'Automatic (Delayed Start)' }
				}
				Catch { }
			}
			
			Write-Log -Message "Service [$Name] startup mode is set to [$ServiceStartMode]." -Source ${CmdletName}
			Write-Output -InputObject $ServiceStartMode
		}
		Catch
		{
			Write-Log -Message "Failed to get the service [$Name] startup mode. `n$(Resolve-Error)" -Source ${CmdletName} -Severity 3
			If (-not $ContinueOnError)
			{
				Throw "Failed to get the service [$Name] startup mode: $($_.Exception.Message)"
			}
		}
	}
	End
	{
		Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -Footer
	}
}
#endregion

#region Function Set-ServiceStartMode
Function Set-ServiceStartMode
{
<#
.SYNOPSIS
	Set the service startup mode.
.DESCRIPTION
	Set the service startup mode.
.PARAMETER Name
	Specify the name of the service.
.PARAMETER ComputerName
	Specify the name of the computer. Default is: the local computer.
.PARAMETER StartMode
	Specify startup mode for the service. Options: Automatic, Automatic (Delayed Start), Manual, Disabled, Boot, System.
.PARAMETER ContinueOnError
	Continue if an error is encountered. Default is: $true.
.EXAMPLE
	Set-ServiceStartMode -Name 'wuauserv' -StartMode 'Automatic (Delayed Start)'
.NOTES
.LINK
	http://psappdeploytoolkit.com
#>
	[CmdLetBinding()]
	Param (
		[Parameter(Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
		[string]$Name,
		[Parameter(Mandatory = $false)]
		[ValidateNotNullOrEmpty()]
		[string]$ComputerName = $env:ComputerName,
		[Parameter(Mandatory = $true)]
		[ValidateSet('Automatic', 'Automatic (Delayed Start)', 'Manual', 'Disabled', 'Boot', 'System')]
		[string]$StartMode,
		[Parameter(Mandatory = $false)]
		[ValidateNotNullOrEmpty()]
		[boolean]$ContinueOnError = $true
	)
	Begin
	{
		[string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
		Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -CmdletBoundParameters $PSBoundParameters -Header
	}
	Process
	{
		Try
		{
			## If on lower than Windows Vista and 'Automatic (Delayed Start)' selected, then change to 'Automatic' because 'Delayed Start' is not supported.
			If (($StartMode -eq 'Automatic (Delayed Start)') -and (([version]$envOSVersion).Major -lt 6)) { $StartMode = 'Automatic' }
			
			Write-Log -Message "Set service [$Name] startup mode to [$StartMode]." -Source ${CmdletName}
			
			## Set the name of the start up mode that will be passed to sc.exe
			[string]$ScExeStartMode = $StartMode
			If ($StartMode -eq 'Automatic') { $ScExeStartMode = 'Auto' }
			If ($StartMode -eq 'Automatic (Delayed Start)') { $ScExeStartMode = 'Delayed-Auto' }
			If ($StartMode -eq 'Manual') { $ScExeStartMode = 'Demand' }
			
			## Set the start up mode using sc.exe. Note: we found that the ChangeStartMode method in the Win32_Service WMI class set services to 'Automatic (Delayed Start)' even when you specified 'Automatic' on Win7, Win8, and Win10.
			$ChangeStartMode = & sc.exe config $Name start= $ScExeStartMode
			
			If ($global:LastExitCode -ne 0)
			{
				Throw "sc.exe failed with exit code [$($global:LastExitCode)] and message [$ChangeStartMode]."
			}
			
			Write-Log -Message "Successfully set service [$Name] startup mode to [$StartMode]." -Source ${CmdletName}
		}
		Catch
		{
			Write-Log -Message "Failed to set service [$Name] startup mode to [$StartMode]. `n$(Resolve-Error)" -Source ${CmdletName} -Severity 3
			If (-not $ContinueOnError)
			{
				Throw "Failed to set service [$Name] startup mode to [$StartMode]: $($_.Exception.Message)"
			}
		}
	}
	End
	{
		Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -Footer
	}
}
#endregion

#region Function New-MsiTransform
Function New-MsiTransform
{
<#
.SYNOPSIS
	Create a transform file for an MSI database.
.DESCRIPTION
	Create a transform file for an MSI database and create/modify properties in the Properties table.
.DEPENDENCIES
	Invoke-ObjectMethod
	Resolve-Error
	Set-MsiProperty
.PARAMETER MsiPath
	Specify the path to an MSI file.
.PARAMETER ApplyTransformPath
	Specify the path to a transform which should be applied to the MSI database before any new properties are created or modified.
.PARAMETER NewTransformPath
	Specify the path where the new transform file with the desired properties will be created. If a transform file of the same name already exists, it will be deleted before a new one is created.
	Default is: a) If -ApplyTransformPath was specified but not -NewTransformPath, then <ApplyTransformPath>.new.mst
				b) If only -MsiPath was specified, then <MsiPath>.mst
.PARAMETER TransformProperties
	Hashtable which contains calls to Set-MsiProperty for configuring the desired properties which should be included in new transform file.
	Example hashtable: [hashtable]$TransformProperties = @{ 'ALLUSERS' = '1' }
.PARAMETER ContinueOnError
	Continue if an error is encountered. Default is: $true.
.EXAMPLE
	[hashtable]$TransformProperties = {
		'ALLUSERS' = '1'
		'AgreeToLicense' = 'Yes'
		'REBOOT' = 'ReallySuppress'
		'RebootYesNo' = 'No'
		'ROOTDRIVE' = 'C:'
	}
	New-MsiTransform -MsiPath 'C:\Temp\PSADTInstall.msi' -TransformProperties $TransformProperties
.NOTES
.LINK
	http://psappdeploytoolkit.com
#>
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $true)]
		[ValidateScript({ Test-Path -LiteralPath $_ -PathType 'Leaf' })]
		[string]$MsiPath,
		[Parameter(Mandatory = $false)]
		[ValidateScript({ Test-Path -LiteralPath $_ -PathType 'Leaf' })]
		[string]$ApplyTransformPath,
		[Parameter(Mandatory = $false)]
		[ValidateNotNullorEmpty()]
		[string]$NewTransformPath,
		[Parameter(Mandatory = $true)]
		[ValidateNotNullorEmpty()]
		[hashtable]$TransformProperties,
		[Parameter(Mandatory = $false)]
		[ValidateNotNullorEmpty()]
		[boolean]$ContinueOnError = $true
	)
	
	Begin
	{
		## Get the name of this function and write header
		[string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
		
		Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -CmdletBoundParameters $PSBoundParameters -Header
		
		## Define properties for how the MSI database is opened
		[int32]$msiOpenDatabaseModeReadOnly = 0
		[int32]$msiOpenDatabaseModeTransact = 1
		[int32]$msiViewModifyUpdate = 2
		[int32]$msiViewModifyReplace = 4
		[int32]$msiViewModifyDelete = 6
		[int32]$msiTransformErrorNone = 0
		[int32]$msiTransformValidationNone = 0
		[int32]$msiSuppressApplyTransformErrors = 63
	}
	Process
	{
		Try
		{
			Write-Log -Message "Create a transform file for MSI [$MsiPath]." -Source ${CmdletName}
			
			## Discover the parent folder that the MSI file resides in
			[string]$MsiParentFolder = Split-Path -Path $MsiPath -Parent -ErrorAction 'Stop'
			
			## Create a temporary file name for storing a second copy of the MSI database
			[string]$TempMsiPath = Join-Path -Path $MsiParentFolder -ChildPath ([IO.Path]::GetFileName(([IO.Path]::GetTempFileName()))) -ErrorAction 'Stop'
			
			## Create a second copy of the MSI database
			Write-Log -Message "Copy MSI database in path [$MsiPath] to destination [$TempMsiPath]." -Source ${CmdletName}
			$null = Copy-Item -LiteralPath $MsiPath -Destination $TempMsiPath -Force -ErrorAction 'Stop'
			
			## Create a Windows Installer object
			[__comobject]$Installer = New-Object -ComObject 'WindowsInstaller.Installer' -ErrorAction 'Stop'
			
			## Open both copies of the MSI database
			#  Open the original MSI database in read only mode
			Write-Log -Message "Open the MSI database [$MsiPath] in read only mode." -Source ${CmdletName}
			[__comobject]$MsiPathDatabase = Invoke-ObjectMethod -InputObject $Installer -MethodName 'OpenDatabase' -ArgumentList @($MsiPath, $msiOpenDatabaseModeReadOnly)
			#  Open the temporary copy of the MSI database in view/modify/update mode
			Write-Log -Message "Open the MSI database [$TempMsiPath] in view/modify/update mode." -Source ${CmdletName}
			[__comobject]$TempMsiPathDatabase = Invoke-ObjectMethod -InputObject $Installer -MethodName 'OpenDatabase' -ArgumentList @($TempMsiPath, $msiViewModifyUpdate)
			
			## If a MSI transform file was specified, then apply it to the temporary copy of the MSI database
			If ($ApplyTransformPath)
			{
				Write-Log -Message "Apply transform file [$ApplyTransformPath] to MSI database [$TempMsiPath]." -Source ${CmdletName}
				$null = Invoke-ObjectMethod -InputObject $TempMsiPathDatabase -MethodName 'ApplyTransform' -ArgumentList @($ApplyTransformPath, $msiSuppressApplyTransformErrors)
			}
			
			## Determine the path for the new transform file that will be generated
			If (-not $NewTransformPath)
			{
				If ($ApplyTransformPath)
				{
					[string]$NewTransformFileName = [IO.Path]::GetFileNameWithoutExtension($ApplyTransformPath) + '.new' + [IO.Path]::GetExtension($ApplyTransformPath)
				}
				Else
				{
					[string]$NewTransformFileName = [IO.Path]::GetFileNameWithoutExtension($MsiPath) + '.mst'
				}
				[string]$NewTransformPath = Join-Path -Path $MsiParentFolder -ChildPath $NewTransformFileName -ErrorAction 'Stop'
			}
			
			## Set the MSI properties in the temporary copy of the MSI database
			$TransformProperties.GetEnumerator() | ForEach-Object { Set-MsiProperty -DataBase $TempMsiPathDatabase -PropertyName $_.Key -PropertyValue $_.Value }
			
			## Commit the new properties to the temporary copy of the MSI database
			$null = Invoke-ObjectMethod -InputObject $TempMsiPathDatabase -MethodName 'Commit'
			
			## Reopen the temporary copy of the MSI database in read only mode
			#  Release the database object for the temporary copy of the MSI database
			$null = [Runtime.Interopservices.Marshal]::ReleaseComObject($TempMsiPathDatabase)
			#  Open the temporary copy of the MSI database in read only mode
			Write-Log -Message "Re-open the MSI database [$TempMsiPath] in read only mode." -Source ${CmdletName}
			[__comobject]$TempMsiPathDatabase = Invoke-ObjectMethod -InputObject $Installer -MethodName 'OpenDatabase' -ArgumentList @($TempMsiPath, $msiOpenDatabaseModeReadOnly)
			
			## Delete the new transform file path if it already exists
			If (Test-Path -LiteralPath $NewTransformPath -PathType 'Leaf' -ErrorAction 'Stop')
			{
				Write-Log -Message "A transform file of the same name already exists. Deleting transform file [$NewTransformPath]." -Source ${CmdletName}
				$null = Remove-Item -LiteralPath $NewTransformPath -Force -ErrorAction 'Stop'
			}
			
			## Generate the new transform file by taking the difference between the temporary copy of the MSI database and the original MSI database
			Write-Log -Message "Generate new transform file [$NewTransformPath]." -Source ${CmdletName}
			$null = Invoke-ObjectMethod -InputObject $TempMsiPathDatabase -MethodName 'GenerateTransform' -ArgumentList @($MsiPathDatabase, $NewTransformPath)
			$null = Invoke-ObjectMethod -InputObject $TempMsiPathDatabase -MethodName 'CreateTransformSummaryInfo' -ArgumentList @($MsiPathDatabase, $NewTransformPath, $msiTransformErrorNone, $msiTransformValidationNone)
			
			If (Test-Path -LiteralPath $NewTransformPath -PathType 'Leaf' -ErrorAction 'Stop')
			{
				Write-Log -Message "Successfully created new transform file in path [$NewTransformPath]." -Source ${CmdletName}
			}
			Else
			{
				Throw "Failed to generate transform file in path [$NewTransformPath]."
			}
		}
		Catch
		{
			Write-Log -Message "Failed to create new transform file in path [$NewTransformPath]. `n$(Resolve-Error)" -Severity 3 -Source ${CmdletName}
			If (-not $ContinueOnError)
			{
				Throw "Failed to create new transform file in path [$NewTransformPath]: $($_.Exception.Message)"
			}
		}
		Finally
		{
			Try { $null = [Runtime.Interopservices.Marshal]::ReleaseComObject($TempMsiPathDatabase) }
			Catch { }
			Try { $null = [Runtime.Interopservices.Marshal]::ReleaseComObject($MsiPathDatabase) }
			Catch { }
			Try { $null = [Runtime.Interopservices.Marshal]::ReleaseComObject($Installer) }
			Catch { }
			Try
			{
				## Delete the temporary copy of the MSI database
				If (Test-Path -LiteralPath $TempMsiPath -PathType 'Leaf' -ErrorAction 'Stop')
				{
					$null = Remove-Item -LiteralPath $TempMsiPath -Force -ErrorAction 'Stop'
				}
			}
			Catch { }
		}
	}
	End
	{
		Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -Footer
	}
}
#endregion

#region Function Get-IniValue
Function Get-IniValue
{
<#
.SYNOPSIS
	Parses an INI file and returns the value of the specified section and key.
.DESCRIPTION
	Parses an INI file and returns the value of the specified section and key.
.DEPENDENCIES
	Resolve-Error
.PARAMETER FilePath
	Path to the INI file.
.PARAMETER Section
	Section within the INI file.
.PARAMETER Key
	Key within the section of the INI file.
.PARAMETER ContinueOnError
	Continue if an error is encountered. Default is: $true.
.EXAMPLE
	Get-IniValue -FilePath "$envProgramFilesX86\IBM\Notes\notes.ini" -Section 'Notes' -Key 'KeyFileName'
.NOTES
.LINK
	http://psappdeploytoolkit.com
#>
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $true)]
		[ValidateNotNullorEmpty()]
		[string]$FilePath,
		[Parameter(Mandatory = $true)]
		[ValidateNotNullorEmpty()]
		[string]$Section,
		[Parameter(Mandatory = $true)]
		[ValidateNotNullorEmpty()]
		[string]$Key,
		[Parameter(Mandatory = $false)]
		[ValidateNotNullorEmpty()]
		[boolean]$ContinueOnError = $true
	)
	
	Begin
	{
		## Get the name of this function and write header
		[string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
		Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -CmdletBoundParameters $PSBoundParameters -Header
	}
	Process
	{
		Try
		{
			Write-Log -Message "Read INI Key: [Section = $Section] [Key = $Key]." -Source ${CmdletName}
			
			If (-not (Test-Path -LiteralPath $FilePath -PathType 'Leaf')) { Throw "File [$filePath] could not be found." }
			
			$IniValue = [PSADT.IniFile]::GetIniValue($Section, $Key, $FilePath)
			Write-Log -Message "INI Key Value: [Section = $Section] [Key = $Key] [Value = $IniValue]." -Source ${CmdletName}
			
			Write-Output -InputObject $IniValue
		}
		Catch
		{
			Write-Log -Message "Failed to read INI file key value. `n$(Resolve-Error)" -Severity 3 -Source ${CmdletName}
			If (-not $ContinueOnError)
			{
				Throw "Failed to read INI file key value: $($_.Exception.Message)"
			}
		}
	}
	End
	{
		Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -Footer
	}
}
#endregion

#region Function Set-IniValue
Function Set-IniValue
{
<#
.SYNOPSIS
	Opens an INI file and sets the value of the specified section and key.
.DESCRIPTION
	Opens an INI file and sets the value of the specified section and key.
.DEPENDENCIES
	Resolve-Error
.PARAMETER FilePath
	Path to the INI file.
.PARAMETER Section
	Section within the INI file.
.PARAMETER Key
	Key within the section of the INI file.
.PARAMETER Value
	Value for the key within the section of the INI file. To remove a value, set this variable to $null.
.PARAMETER ContinueOnError
	Continue if an error is encountered. Default is: $true.
.EXAMPLE
	Set-IniValue -FilePath "$envProgramFilesX86\IBM\Notes\notes.ini" -Section 'Notes' -Key 'KeyFileName' -Value 'MyFile.ID'
.NOTES
.LINK
	http://psappdeploytoolkit.com
#>
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $true)]
		[ValidateNotNullorEmpty()]
		[string]$FilePath,
		[Parameter(Mandatory = $true)]
		[ValidateNotNullorEmpty()]
		[string]$Section,
		[Parameter(Mandatory = $true)]
		[ValidateNotNullorEmpty()]
		[string]$Key,
		# Don't strongly type this variable as [string] b/c PowerShell replaces [string]$Value = $null with an empty string
		[Parameter(Mandatory = $true)]
		[AllowNull()]
		$Value,
		[Parameter(Mandatory = $false)]
		[ValidateNotNullorEmpty()]
		[boolean]$ContinueOnError = $true
	)
	
	Begin
	{
		## Get the name of this function and write header
		[string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
		Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -CmdletBoundParameters $PSBoundParameters -Header
	}
	Process
	{
		Try
		{
			Write-Log -Message "Write INI Key Value: [Section = $Section] [Key = $Key] [Value = $Value]." -Source ${CmdletName}
			
			If (-not (Test-Path -LiteralPath $FilePath -PathType 'Leaf')) { Throw "File [$filePath] could not be found." }
			
			[PSADT.IniFile]::SetIniValue($Section, $Key, ([Text.StringBuilder]$Value), $FilePath)
		}
		Catch
		{
			Write-Log -Message "Failed to write INI file key value. `n$(Resolve-Error)" -Severity 3 -Source ${CmdletName}
			If (-not $ContinueOnError)
			{
				Throw "Failed to write INI file key value: $($_.Exception.Message)"
			}
		}
	}
	End
	{
		Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -Footer
	}
}
#endregion

#region Function Get-FileVersion
Function Get-FileVersion
{
<#
.SYNOPSIS
	Gets the version of the specified file
.DESCRIPTION
	Gets the version of the specified file
.DEPENDENCIES
	Resolve-Error
.PARAMETER File
	Path of the file
.PARAMETER ContinueOnError
	Continue if an error is encountered. Default is: $true.
.EXAMPLE
	Get-FileVersion -File "$envProgramFilesX86\Adobe\Reader 11.0\Reader\AcroRd32.exe"
.NOTES
.LINK
	http://psappdeploytoolkit.com
#>
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $true)]
		[ValidateNotNullorEmpty()]
		[string]$File,
		[Parameter(Mandatory = $false)]
		[ValidateNotNullOrEmpty()]
		[boolean]$ContinueOnError = $true
	)
	
	Begin
	{
		## Get the name of this function and write header
		[string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
		Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -CmdletBoundParameters $PSBoundParameters -Header
	}
	Process
	{
		Try
		{
			Write-Log -Message "Get file version info for file [$file]." -Source ${CmdletName}
			
			If (Test-Path -LiteralPath $File -PathType 'Leaf')
			{
				$fileVersion = (Get-Command -Name $file -ErrorAction 'Stop').FileVersionInfo.FileVersion
				If ($fileVersion)
				{
					## Remove product information to leave only the file version
					$fileVersion = ($fileVersion -split ' ' | Select-Object -First 1)
					
					Write-Log -Message "File version is [$fileVersion]." -Source ${CmdletName}
					Write-Output -InputObject $fileVersion
				}
				Else
				{
					Write-Log -Message 'No file version information found.' -Source ${CmdletName}
				}
			}
			Else
			{
				Throw "File path [$file] does not exist."
			}
		}
		Catch
		{
			Write-Log -Message "Failed to get file version info. `n$(Resolve-Error)" -Severity 3 -Source ${CmdletName}
			If (-not $ContinueOnError)
			{
				Throw "Failed to get file version info: $($_.Exception.Message)"
			}
		}
	}
	End
	{
		Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -Footer
	}
}
#endregion

#region Function Get-ScheduledTask
Function Get-ScheduledTask
{
<#
.SYNOPSIS
	Retrieve all details for scheduled tasks on the local computer.
.DESCRIPTION
	Retrieve all details for scheduled tasks on the local computer using schtasks.exe. All property names have spaces and colons removed.
.DEPENDENCIES
	
.PARAMETER TaskName
	Specify the name of the scheduled task to retrieve details for. Uses regex match to find scheduled task.
.PARAMETER ContinueOnError
	Continue if an error is encountered. Default: $true.
.EXAMPLE
	Get-ScheduledTask
	To display a list of all scheduled task properties.
.EXAMPLE
	Get-ScheduledTask | Out-GridView
	To display a grid view of all scheduled task properties.
.EXAMPLE
	Get-ScheduledTask | Select-Object -Property TaskName
	To display a list of all scheduled task names.
.NOTES
.LINK
	http://psappdeploytoolkit.com
#>
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $false)]
		[ValidateNotNullOrEmpty()]
		[string]$TaskName,
		[Parameter(Mandatory = $false)]
		[ValidateNotNullOrEmpty()]
		[boolean]$ContinueOnError = $true
	)
	
	Begin
	{
		## Get the name of this function and write header
		[string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
		Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -CmdletBoundParameters $PSBoundParameters -Header
		
		If (-not $exeSchTasks) { [string]$exeSchTasks = "$env:WINDIR\system32\schtasks.exe" }
		[psobject[]]$ScheduledTasks = @()
	}
	Process
	{
		Try
		{
			Write-Log -Message 'Retrieve Scheduled Tasks...' -Source ${CmdletName}
			[string[]]$exeSchtasksResults = & $exeSchTasks /Query /V /FO CSV
			If ($global:LastExitCode -ne 0) { Throw "Failed to retrieve scheduled tasks using [$exeSchTasks]." }
			[psobject[]]$SchtasksResults = $exeSchtasksResults | ConvertFrom-CSV -Header 'HostName', 'TaskName', 'Next Run Time', 'Status', 'Logon Mode', 'Last Run Time', 'Last Result', 'Author', 'Task To Run', 'Start In', 'Comment', 'Scheduled Task State', 'Idle Time', 'Power Management', 'Run As User', 'Delete Task If Not Rescheduled', 'Stop Task If Runs X Hours and X Mins', 'Schedule', 'Schedule Type', 'Start Time', 'Start Date', 'End Date', 'Days', 'Months', 'Repeat: Every', 'Repeat: Until: Time', 'Repeat: Until: Duration', 'Repeat: Stop If Still Running' -ErrorAction 'Stop'
			
			If ($SchtasksResults)
			{
				ForEach ($SchtasksResult in $SchtasksResults)
				{
					If ($SchtasksResult.TaskName -match $TaskName)
					{
						$SchtasksResult | Get-Member -MemberType 'Properties' |
						ForEach-Object -Begin {
							[hashtable]$Task = @{ }
						} -Process {
							## Remove spaces and colons in property names. Do not set property value if line being processed is a column header (this will only work on English language machines).
							($Task.($($_.Name).Replace(' ', '').Replace(':', ''))) = If ($_.Name -ne $SchtasksResult.($_.Name)) { $SchtasksResult.($_.Name) }
						} -End {
							## Only add task to the custom object if all property values are not empty
							If (($Task.Values | Select-Object -Unique | Measure-Object).Count)
							{
								$ScheduledTasks += New-Object -TypeName 'PSObject' -Property $Task
							}
						}
					}
				}
			}
		}
		Catch
		{
			Write-Log -Message "Failed to retrieve scheduled tasks. `n$(Resolve-Error)" -Severity 3 -Source ${CmdletName}
			If (-not $ContinueOnError)
			{
				Throw "Failed to retrieve scheduled tasks: $($_.Exception.Message)"
			}
		}
	}
	End
	{
		Write-Output -InputObject $ScheduledTasks
		Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -Footer
	}
}
#endregion

#region Function Get-RunningProcesses
Function Get-RunningProcesses
{
<#
.SYNOPSIS
	Gets the processes that are running from a custom list of process objects and also adds a property called ProcessDescription.
.DESCRIPTION
	Gets the processes that are running from a custom list of process objects and also adds a property called ProcessDescription.
.DEPENDENCIES
	
.PARAMETER ProcessObjects
	Custom object containing the process objects to search for.
.EXAMPLE
	Get-RunningProcesses
.NOTES
	This is an internal script function and should typically not be called directly.
.LINK
	http://psappdeploytoolkit.com
#>
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $false, Position = 0)]
		[psobject[]]$ProcessObjects,
		[Parameter(Mandatory = $false, Position = 1)]
		[switch]$DisableLogging
	)
	
	Begin
	{
		## Get the name of this function and write header
		[string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
		Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -CmdletBoundParameters $PSBoundParameters -Header
	}
	Process
	{
		If ($processObjects)
		{
			[string]$runningAppsCheck = ($processObjects | ForEach-Object { $_.ProcessName }) -join ','
			If (-not ($DisableLogging))
			{
				Write-Log -Message "Check for running application(s) [$runningAppsCheck]..." -Source ${CmdletName}
			}
			## Create an array of process names to search for
			[string[]]$processNames = $processObjects | ForEach-Object { $_.ProcessName }
			
			## Get all running processes and escape special characters. Match against the process names to search for to find running processes.
			[Diagnostics.Process[]]$runningProcesses = Get-Process | Where-Object { $processNames -contains $_.ProcessName }
			
			If ($runningProcesses)
			{
				[string]$runningProcessList = ($runningProcesses | ForEach-Object { $_.ProcessName } | Select-Object -Unique) -join ','
				If (-not ($DisableLogging))
				{
					Write-Log -Message "The following processes are running: [$runningProcessList]." -Source ${CmdletName}
					Write-Log -Message 'Resolve process descriptions...' -Source ${CmdletName}
				}
				## Resolve the running process names to descriptions
				ForEach ($runningProcess in $runningProcesses)
				{
					ForEach ($processObject in $processObjects)
					{
						If ($runningProcess.ProcessName -eq $processObject.ProcessName)
						{
							If ($processObject.ProcessDescription)
							{
								#  The description of the process provided as a Parameter to the function, e.g. -ProcessName "winword=Microsoft Office Word".
								$runningProcess | Add-Member -MemberType 'NoteProperty' -Name 'ProcessDescription' -Value $processObject.ProcessDescription -Force -PassThru -ErrorAction 'SilentlyContinue'
							}
							ElseIf ($runningProcess.Description)
							{
								#  If the process already has a description field specified, then use it
								$runningProcess | Add-Member -MemberType 'NoteProperty' -Name 'ProcessDescription' -Value $runningProcess.Description -Force -PassThru -ErrorAction 'SilentlyContinue'
							}
							Else
							{
								#  Fall back on the process name if no description is provided by the process or as a parameter to the function
								$runningProcess | Add-Member -MemberType 'NoteProperty' -Name 'ProcessDescription' -Value $runningProcess.ProcessName -Force -PassThru -ErrorAction 'SilentlyContinue'
							}
						}
					}
				}
			}
			Else
			{
				If (-not ($DisableLogging))
				{
					Write-Log -Message 'Application(s) are not running.' -Source ${CmdletName}
				}
			}
			Write-Output -InputObject $runningProcesses
		}
	}
	End
	{
		Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -Footer
	}
}
#endregion

#region Function Get-UniversalDate
Function Get-UniversalDate
{
<#
.SYNOPSIS
	Returns the date/time for the local culture in a universal sortable date time pattern.
.DESCRIPTION
	Converts the current datetime or a datetime string for the current culture into a universal sortable date time pattern, e.g. 2013-08-22 11:51:52Z
.DEPENDENCIES
	Resolve-Error
.PARAMETER DateTime
	Specify the DateTime in the current culture.
.PARAMETER ContinueOnError
	Continue if an error is encountered. Default: $false.
.EXAMPLE
	Get-UniversalDate
	Returns the current date in a universal sortable date time pattern.
.EXAMPLE
	Get-UniversalDate -DateTime '25/08/2013'
	Returns the date for the current culture in a universal sortable date time pattern.
.NOTES
.LINK
	http://psappdeploytoolkit.com
#>
	[CmdletBinding()]
	Param (
		#  Get the current date
		[Parameter(Mandatory = $false)]
		[ValidateNotNullorEmpty()]
		[string]$DateTime = ((Get-Date -Format ($culture).DateTimeFormat.UniversalDateTimePattern).ToString()),
		[Parameter(Mandatory = $false)]
		[ValidateNotNullorEmpty()]
		[boolean]$ContinueOnError = $false
	)
	
	Begin
	{
		## Get the name of this function and write header
		[string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
		Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -CmdletBoundParameters $PSBoundParameters -Header
	}
	Process
	{
		Try
		{
			## If a universal sortable date time pattern was provided, remove the Z, otherwise it could get converted to a different time zone.
			If ($DateTime -match 'Z$') { $DateTime = $DateTime -replace 'Z$', '' }
			[datetime]$DateTime = [datetime]::Parse($DateTime, $culture)
			
			## Convert the date to a universal sortable date time pattern based on the current culture
			Write-Log -Message "Convert the date [$DateTime] to a universal sortable date time pattern based on the current culture [$($culture.Name)]." -Source ${CmdletName}
			[string]$universalDateTime = (Get-Date -Date $DateTime -Format ($culture).DateTimeFormat.UniversalSortableDateTimePattern -ErrorAction 'Stop').ToString()
			Write-Output -InputObject $universalDateTime
		}
		Catch
		{
			Write-Log -Message "The specified date/time [$DateTime] is not in a format recognized by the current culture [$($culture.Name)]. `n$(Resolve-Error)" -Severity 3 -Source ${CmdletName}
			If (-not $ContinueOnError)
			{
				Throw "The specified date/time [$DateTime] is not in a format recognized by the current culture: $($_.Exception.Message)"
			}
		}
	}
	End
	{
		Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -Footer
	}
}
#endregion

#region Function Write-Log
Function Write-Log{
<#
.SYNOPSIS
	Write messages to a log file in CMTrace.exe compatible format or Legacy text file format.
.DESCRIPTION
	Write messages to a log file in CMTrace.exe compatible format or Legacy text file format and optionally display in the console.
.DEPENDENCIES
	$LogName
	$Resolve-Error
.PARAMETER Message
	The message to write to the log file or output to the console.
.PARAMETER Severity
	Defines message type. When writing to console or CMTrace.exe log format, it allows highlighting of message type.
	Options: 1 = Information (default), 2 = Warning (highlighted in yellow), 3 = Error (highlighted in red)
.PARAMETER Source
	The source of the message being logged.
.PARAMETER ScriptSection
	The heading for the portion of the script that is being executed. Default is: $script:installPhase.
.PARAMETER LogType
	Choose whether to write a CMTrace.exe compatible log file or a Legacy text log file.
.PARAMETER LogFileDirectory
	Set the directory where the log file will be saved.
.PARAMETER LogFileName
	Set the name of the log file.
.PARAMETER MaxLogFileSizeMB
	Maximum file size limit for log file in megabytes (MB). Default is 10 MB.
.PARAMETER WriteHost
	Write the log message to the console.
.PARAMETER ContinueOnError
	Suppress writing log message to console on failure to write message to log file. Default is: $true.
.PARAMETER PassThru
	Return the message that was passed to the function
.PARAMETER DebugMessage
	Specifies that the message is a debug message. Debug messages only get logged if -LogDebugMessage is set to $true.
.PARAMETER LogDebugMessage
	Debug messages only get logged if this parameter is set to $true in the config XML file.
.EXAMPLE
	Write-Log -Message "Installing patch MS15-031" -Source 'Add-Patch' -LogType 'CMTrace'
.EXAMPLE
	Write-Log -Message "Script is running on Windows 8" -Source 'Test-ValidOS' -LogType 'Legacy'
.NOTES
.LINK
	http://psappdeploytoolkit.com
#>
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $true, Position = 0)]
		[AllowEmptyCollection()]
		[string[]]$Message,
		[Parameter(Mandatory = $false, Position = 1)]
		[ValidateRange(1, 3)]
		[int16]$Severity = 1,
		[Parameter(Mandatory = $false, Position = 2)]
		[ValidateNotNull()]
		[string]$Source = '',
		[Parameter(Mandatory = $false, Position = 3)]
		[ValidateNotNullorEmpty()]
		[string]$ScriptSection = $script:Phase,
		[Parameter(Mandatory = $false, Position = 4)]
		[ValidateSet('CMTrace', 'Legacy')]
		[string]$LogType = $configToolkitLogStyle,
		[Parameter(Mandatory = $false, Position = 5)]
		[ValidateNotNullorEmpty()]
		[string]$LogFileDirectory = $configToolkitLogDir,
		[Parameter(Mandatory = $false, Position = 6)]
		[ValidateNotNullorEmpty()]
		[string]$LogFileName = $logName,
		[Parameter(Mandatory = $false, Position = 7)]
		[ValidateNotNullorEmpty()]
		[decimal]$MaxLogFileSizeMB = $configToolkitLogMaxSize,
		[Parameter(Mandatory = $false, Position = 8)]
		[ValidateNotNullorEmpty()]
		[boolean]$WriteHost = $configToolkitLogWriteToHost,
		[Parameter(Mandatory = $false, Position = 9)]
		[ValidateNotNullorEmpty()]
		[boolean]$ContinueOnError = $true,
		[Parameter(Mandatory = $false, Position = 10)]
		[switch]$PassThru = $false,
		[Parameter(Mandatory = $false, Position = 11)]
		[switch]$DebugMessage = $false,
		[Parameter(Mandatory = $false, Position = 12)]
		[boolean]$LogDebugMessage = $configToolkitLogDebugMessage
	)
	
	Begin
	{
		## Get the name of this function
		[string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
		
		## Logging Variables
		#  Log file date/time
		[string]$LogTime = (Get-Date -Format 'HH\:mm\:ss.fff').ToString()
		[string]$LogDate = (Get-Date -Format 'MM-dd-yyyy').ToString()
		If (-not (Test-Path -LiteralPath 'variable:LogTimeZoneBias')) { [int32]$script:LogTimeZoneBias = [timezone]::CurrentTimeZone.GetUtcOffset([datetime]::Now).TotalMinutes }
		[string]$LogTimePlusBias = $LogTime + $script:LogTimeZoneBias
		#  Initialize variables
		[boolean]$ExitLoggingFunction = $false
		If (-not (Test-Path -LiteralPath 'variable:DisableLogging')) { $DisableLogging = $false }
		#  Check if the script section is defined
		[boolean]$ScriptSectionDefined = [boolean](-not [string]::IsNullOrEmpty($ScriptSection))
		#  Get the file name of the source script
		Try
		{
			If ($script:MyInvocation.Value.ScriptName)
			{
				[string]$ScriptSource = Split-Path -Path $script:MyInvocation.Value.ScriptName -Leaf -ErrorAction 'Stop'
			}
			Else
			{
				[string]$ScriptSource = Split-Path -Path $script:MyInvocation.MyCommand.Definition -Leaf -ErrorAction 'Stop'
			}
		}
		Catch
		{
			$ScriptSource = ''
		}
		
		## Create script block for generating CMTrace.exe compatible log entry
		[scriptblock]$CMTraceLogString = {
			Param (
				[string]$lMessage,
				[string]$lSource,
				[int16]$lSeverity
			)
			"<![LOG[$([Security.Principal.WindowsIdentity]::GetCurrent().Name): $lMessage]LOG]!>" + "<time=`"$LogTimePlusBias`" " + "date=`"$LogDate`" " + "component=`"$lSource`" " + "context=`"`" " + "type=`"$lSeverity`" " + "thread=`"$PID`" " + "file=`"`">"
		}
		
		## Create script block for writing log entry to the console
		[scriptblock]$WriteLogLineToHost = {
			Param (
				[string]$lTextLogLine,
				[int16]$lSeverity
			)
			If ($WriteHost)
			{
				#  Only output using color options if running in a host which supports colors.
				If ($Host.UI.RawUI.ForegroundColor)
				{
					Switch ($lSeverity)
					{
						3 { Write-Host -Object $lTextLogLine -ForegroundColor 'Red' -BackgroundColor 'Black' }
						2 { Write-Host -Object $lTextLogLine -ForegroundColor 'Yellow' -BackgroundColor 'Black' }
						1 { Write-Host -Object $lTextLogLine }
					}
				}
				#  If executing "powershell.exe -File <filename>.ps1 > log.txt", then all the Write-Host calls are converted to Write-Output calls so that they are included in the text log.
				Else
				{
					Write-Output -InputObject $lTextLogLine
				}
			}
		}
		
		## Exit function if it is a debug message and logging debug messages is not enabled in the config XML file
		If (($DebugMessage) -and (-not $LogDebugMessage)) { [boolean]$ExitLoggingFunction = $true; Return }
		## Exit function if logging to file is disabled and logging to console host is disabled
		If (($DisableLogging) -and (-not $WriteHost)) { [boolean]$ExitLoggingFunction = $true; Return }
		## Exit Begin block if logging is disabled
		If ($DisableLogging) { Return }
		## Exit function function if it is an [Initialization] message and the toolkit has been relaunched
		If (($AsyncToolkitLaunch) -and ($ScriptSection -eq 'Initialization')) { [boolean]$ExitLoggingFunction = $true; Return }
		
		## Create the directory where the log file will be saved
		If (-not (Test-Path -LiteralPath $LogFileDirectory -PathType 'Container'))
		{
			Try
			{
				$null = New-Item -Path $LogFileDirectory -Type 'Directory' -Force -ErrorAction 'Stop'
			}
			Catch
			{
				[boolean]$ExitLoggingFunction = $true
				#  If error creating directory, write message to console
				If (-not $ContinueOnError)
				{
					Write-Host -Object "[$LogDate $LogTime] [${CmdletName}] $ScriptSection :: Failed to create the log directory [$LogFileDirectory]. `n$(Resolve-Error)" -ForegroundColor 'Red'
				}
				Return
			}
		}
		
		## Assemble the fully qualified path to the log file
		[string]$LogFilePath = Join-Path -Path $LogFileDirectory -ChildPath $LogFileName
	}
	Process
	{
		## Exit function if logging is disabled
		If ($ExitLoggingFunction) { Return }
		
		ForEach ($Msg in $Message)
		{
			## If the message is not $null or empty, create the log entry for the different logging methods
			[string]$CMTraceMsg = ''
			[string]$ConsoleLogLine = ''
			[string]$LegacyTextLogLine = ''
			If ($Msg)
			{
				#  Create the CMTrace log message
				If ($ScriptSectionDefined) { [string]$CMTraceMsg = "[$ScriptSection] :: $Msg" }
				
				#  Create a Console and Legacy "text" log entry
				[string]$LegacyMsg = "[$LogDate $LogTime]"
				If ($ScriptSectionDefined) { [string]$LegacyMsg += " [$ScriptSection]" }
				If ($Source)
				{
					[string]$ConsoleLogLine = "$LegacyMsg [$Source] :: $Msg"
					Switch ($Severity)
					{
						3 { [string]$LegacyTextLogLine = "$LegacyMsg [$Source] [Error] :: $Msg" }
						2 { [string]$LegacyTextLogLine = "$LegacyMsg [$Source] [Warning] :: $Msg" }
						1 { [string]$LegacyTextLogLine = "$LegacyMsg [$Source] [Info] :: $Msg" }
					}
				}
				Else
				{
					[string]$ConsoleLogLine = "$LegacyMsg :: $Msg"
					Switch ($Severity)
					{
						3 { [string]$LegacyTextLogLine = "$LegacyMsg [Error] :: $Msg" }
						2 { [string]$LegacyTextLogLine = "$LegacyMsg [Warning] :: $Msg" }
						1 { [string]$LegacyTextLogLine = "$LegacyMsg [Info] :: $Msg" }
					}
				}
			}
			
			## Execute script block to create the CMTrace.exe compatible log entry
			[string]$CMTraceLogLine = & $CMTraceLogString -lMessage $CMTraceMsg -lSource $Source -lSeverity $Severity
			
			## Choose which log type to write to file
			If ($LogType -ieq 'CMTrace')
			{
				[string]$LogLine = $CMTraceLogLine
			}
			Else
			{
				[string]$LogLine = $LegacyTextLogLine
			}
			
			## Write the log entry to the log file if logging is not currently disabled
			If (-not $DisableLogging)
			{
				Try
				{
					$LogLine | Out-File -FilePath $LogFilePath -Append -NoClobber -Force -Encoding 'UTF8' -ErrorAction 'Stop'
				}
				Catch
				{
					If (-not $ContinueOnError)
					{
						Write-Host -Object "[$LogDate $LogTime] [$ScriptSection] [${CmdletName}] :: Failed to write message [$Msg] to the log file [$LogFilePath]. `n$(Resolve-Error)" -ForegroundColor 'Red'
					}
				}
			}
			
			## Execute script block to write the log entry to the console if $WriteHost is $true
			& $WriteLogLineToHost -lTextLogLine $ConsoleLogLine -lSeverity $Severity
		}
	}
	End
	{
		## Archive log file if size is greater than $MaxLogFileSizeMB and $MaxLogFileSizeMB > 0
		Try
		{
			If ((-not $ExitLoggingFunction) -and (-not $DisableLogging))
			{
				[IO.FileInfo]$LogFile = Get-ChildItem -LiteralPath $LogFilePath -ErrorAction 'Stop'
				[decimal]$LogFileSizeMB = $LogFile.Length/1MB
				If (($LogFileSizeMB -gt $MaxLogFileSizeMB) -and ($MaxLogFileSizeMB -gt 0))
				{
					## Change the file extension to "lo_"
					[string]$ArchivedOutLogFile = [IO.Path]::ChangeExtension($LogFilePath, 'lo_')
					[hashtable]$ArchiveLogParams = @{ ScriptSection = $ScriptSection; Source = ${CmdletName}; Severity = 2; LogFileDirectory = $LogFileDirectory; LogFileName = $LogFileName; LogType = $LogType; MaxLogFileSizeMB = 0; WriteHost = $WriteHost; ContinueOnError = $ContinueOnError; PassThru = $false }
					
					## Log message about archiving the log file
					$ArchiveLogMessage = "Maximum log file size [$MaxLogFileSizeMB MB] reached. Rename log file to [$ArchivedOutLogFile]."
					Write-Log -Message $ArchiveLogMessage @ArchiveLogParams
					
					## Archive existing log file from <filename>.log to <filename>.lo_. Overwrites any existing <filename>.lo_ file. This is the same method SCCM uses for log files.
					Move-Item -LiteralPath $LogFilePath -Destination $ArchivedOutLogFile -Force -ErrorAction 'Stop'
					
					## Start new log file and Log message about archiving the old log file
					$NewLogMessage = "Previous log file was renamed to [$ArchivedOutLogFile] because maximum log file size of [$MaxLogFileSizeMB MB] was reached."
					Write-Log -Message $NewLogMessage @ArchiveLogParams
				}
			}
		}
		Catch
		{
			## If renaming of file fails, script will continue writing to log file even if size goes over the max file size
		}
		Finally
		{
			If ($PassThru) { Write-Output -InputObject $Message }
		}
	}
}
#endregion

#region Function Resolve-Error
Function Resolve-Error
{
<#
.SYNOPSIS
	Enumerate error record details.
.DESCRIPTION
	Enumerate an error record, or a collection of error record, properties. By default, the details for the last error will be enumerated.
.PARAMETER ErrorRecord
	The error record to resolve. The default error record is the latest one: $global:Error[0]. This parameter will also accept an array of error records.
.PARAMETER Property
	The list of properties to display from the error record. Use "*" to display all properties.
	Default list of error properties is: Message, FullyQualifiedErrorId, ScriptStackTrace, PositionMessage, InnerException
.PARAMETER GetErrorRecord
	Get error record details as represented by $_.
.PARAMETER GetErrorInvocation
	Get error record invocation information as represented by $_.InvocationInfo.
.PARAMETER GetErrorException
	Get error record exception details as represented by $_.Exception.
.PARAMETER GetErrorInnerException
	Get error record inner exception details as represented by $_.Exception.InnerException. Will retrieve all inner exceptions if there is more than one.
.EXAMPLE
	Resolve-Error
.EXAMPLE
	Resolve-Error -Property *
.EXAMPLE
	Resolve-Error -Property InnerException
.EXAMPLE
	Resolve-Error -GetErrorInvocation:$false
.NOTES
.LINK
	http://psappdeploytoolkit.com
#>
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $false, Position = 0, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
		[AllowEmptyCollection()]
		[array]$ErrorRecord,
		[Parameter(Mandatory = $false, Position = 1)]
		[ValidateNotNullorEmpty()]
		[string[]]$Property = ('Message', 'InnerException', 'FullyQualifiedErrorId', 'ScriptStackTrace', 'PositionMessage'),
		[Parameter(Mandatory = $false, Position = 2)]
		[switch]$GetErrorRecord = $true,
		[Parameter(Mandatory = $false, Position = 3)]
		[switch]$GetErrorInvocation = $true,
		[Parameter(Mandatory = $false, Position = 4)]
		[switch]$GetErrorException = $true,
		[Parameter(Mandatory = $false, Position = 5)]
		[switch]$GetErrorInnerException = $true
	)
	
	Begin
	{
		## If function was called without specifying an error record, then choose the latest error that occurred
		If (-not $ErrorRecord)
		{
			If ($global:Error.Count -eq 0)
			{
				#Write-Warning -Message "The `$Error collection is empty"
				Return
			}
			Else
			{
				[array]$ErrorRecord = $global:Error[0]
			}
		}
		
		## Allows selecting and filtering the properties on the error object if they exist
		[scriptblock]$SelectProperty = {
			Param (
				[Parameter(Mandatory = $true)]
				[ValidateNotNullorEmpty()]
				$InputObject,
				[Parameter(Mandatory = $true)]
				[ValidateNotNullorEmpty()]
				[string[]]$Property
			)
			
			[string[]]$ObjectProperty = $InputObject | Get-Member -MemberType '*Property' | Select-Object -ExpandProperty 'Name'
			ForEach ($Prop in $Property)
			{
				If ($Prop -eq '*')
				{
					[string[]]$PropertySelection = $ObjectProperty
					Break
				}
				ElseIf ($ObjectProperty -contains $Prop)
				{
					[string[]]$PropertySelection += $Prop
				}
			}
			Write-Output -InputObject $PropertySelection
		}
		
		#  Initialize variables to avoid error if 'Set-StrictMode' is set
		$LogErrorRecordMsg = $null
		$LogErrorInvocationMsg = $null
		$LogErrorExceptionMsg = $null
		$LogErrorMessageTmp = $null
		$LogInnerMessage = $null
	}
	Process
	{
		If (-not $ErrorRecord) { Return }
		ForEach ($ErrRecord in $ErrorRecord)
		{
			## Capture Error Record
			If ($GetErrorRecord)
			{
				[string[]]$SelectedProperties = & $SelectProperty -InputObject $ErrRecord -Property $Property
				$LogErrorRecordMsg = $ErrRecord | Select-Object -Property $SelectedProperties
			}
			
			## Error Invocation Information
			If ($GetErrorInvocation)
			{
				If ($ErrRecord.InvocationInfo)
				{
					[string[]]$SelectedProperties = & $SelectProperty -InputObject $ErrRecord.InvocationInfo -Property $Property
					$LogErrorInvocationMsg = $ErrRecord.InvocationInfo | Select-Object -Property $SelectedProperties
				}
			}
			
			## Capture Error Exception
			If ($GetErrorException)
			{
				If ($ErrRecord.Exception)
				{
					[string[]]$SelectedProperties = & $SelectProperty -InputObject $ErrRecord.Exception -Property $Property
					$LogErrorExceptionMsg = $ErrRecord.Exception | Select-Object -Property $SelectedProperties
				}
			}
			
			## Display properties in the correct order
			If ($Property -eq '*')
			{
				#  If all properties were chosen for display, then arrange them in the order the error object displays them by default.
				If ($LogErrorRecordMsg) { [array]$LogErrorMessageTmp += $LogErrorRecordMsg }
				If ($LogErrorInvocationMsg) { [array]$LogErrorMessageTmp += $LogErrorInvocationMsg }
				If ($LogErrorExceptionMsg) { [array]$LogErrorMessageTmp += $LogErrorExceptionMsg }
			}
			Else
			{
				#  Display selected properties in our custom order
				If ($LogErrorExceptionMsg) { [array]$LogErrorMessageTmp += $LogErrorExceptionMsg }
				If ($LogErrorRecordMsg) { [array]$LogErrorMessageTmp += $LogErrorRecordMsg }
				If ($LogErrorInvocationMsg) { [array]$LogErrorMessageTmp += $LogErrorInvocationMsg }
			}
			
			If ($LogErrorMessageTmp)
			{
				$LogErrorMessage = 'Error Record:'
				$LogErrorMessage += "`n-------------"
				$LogErrorMsg = $LogErrorMessageTmp | Format-List | Out-String
				$LogErrorMessage += $LogErrorMsg
			}
			
			## Capture Error Inner Exception(s)
			If ($GetErrorInnerException)
			{
				If ($ErrRecord.Exception -and $ErrRecord.Exception.InnerException)
				{
					$LogInnerMessage = 'Error Inner Exception(s):'
					$LogInnerMessage += "`n-------------------------"
					
					$ErrorInnerException = $ErrRecord.Exception.InnerException
					$Count = 0
					
					While ($ErrorInnerException)
					{
						[string]$InnerExceptionSeperator = '~' * 40
						
						[string[]]$SelectedProperties = & $SelectProperty -InputObject $ErrorInnerException -Property $Property
						$LogErrorInnerExceptionMsg = $ErrorInnerException | Select-Object -Property $SelectedProperties | Format-List | Out-String
						
						If ($Count -gt 0) { $LogInnerMessage += $InnerExceptionSeperator }
						$LogInnerMessage += $LogErrorInnerExceptionMsg
						
						$Count++
						$ErrorInnerException = $ErrorInnerException.InnerException
					}
				}
			}
			
			If ($LogErrorMessage) { $Output = $LogErrorMessage }
			If ($LogInnerMessage) { $Output += $LogInnerMessage }
			
			Write-Output -InputObject $Output
			
			If (Test-Path -LiteralPath 'variable:Output') { Clear-Variable -Name 'Output' }
			If (Test-Path -LiteralPath 'variable:LogErrorMessage') { Clear-Variable -Name 'LogErrorMessage' }
			If (Test-Path -LiteralPath 'variable:LogInnerMessage') { Clear-Variable -Name 'LogInnerMessage' }
			If (Test-Path -LiteralPath 'variable:LogErrorMessageTmp') { Clear-Variable -Name 'LogErrorMessageTmp' }
		}
	}
	End
	{
	}
}
#endregion

#region Function Write-FunctionHeaderOrFooter
Function Write-FunctionHeaderOrFooter
{
<#
.SYNOPSIS
	Write the function header or footer to the log upon first entering or exiting a function.
.DESCRIPTION
	Write the "Function Start" message, the bound parameters the function was invoked with, or the "Function End" message when entering or exiting a function.
	Messages are debug messages so will only be logged if LogDebugMessage option is enabled in XML config file.
.PARAMETER CmdletName
	The name of the function this function is invoked from.
.PARAMETER CmdletBoundParameters
	The bound parameters of the function this function is invoked from.
.PARAMETER Header
	Write the function header.
.PARAMETER Footer
	Write the function footer.
.EXAMPLE
	Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -CmdletBoundParameters $PSBoundParameters -Header
.EXAMPLE
	Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -Footer
.NOTES
	This is an internal script function and should typically not be called directly.
.LINK
	http://psappdeploytoolkit.com
#>
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $true)]
		[ValidateNotNullorEmpty()]
		[string]$CmdletName,
		[Parameter(Mandatory = $true, ParameterSetName = 'Header')]
		[AllowEmptyCollection()]
		[hashtable]$CmdletBoundParameters,
		[Parameter(Mandatory = $true, ParameterSetName = 'Header')]
		[switch]$Header,
		[Parameter(Mandatory = $true, ParameterSetName = 'Footer')]
		[switch]$Footer
	)
	
	If ($Header)
	{
		Write-Log -Message 'Function Start' -Source ${CmdletName} -DebugMessage
		
		## Get the parameters that the calling function was invoked with
		[string]$CmdletBoundParameters = $CmdletBoundParameters | Format-Table -Property @{ Label = 'Parameter'; Expression = { "[-$($_.Key)]" } }, @{ Label = 'Value'; Expression = { $_.Value }; Alignment = 'Left' }, @{ Label = 'Type'; Expression = { $_.Value.GetType().Name }; Alignment = 'Left' } -AutoSize -Wrap | Out-String
		If ($CmdletBoundParameters)
		{
			Write-Log -Message "Function invoked with bound parameter(s): `n$CmdletBoundParameters" -Source ${CmdletName} -DebugMessage
		}
		Else
		{
			Write-Log -Message 'Function invoked without any bound parameters.' -Source ${CmdletName} -DebugMessage
		}
	}
	ElseIf ($Footer)
	{
		Write-Log -Message 'Function End' -Source ${CmdletName} -DebugMessage
	}
}
#endregion

#region Function Execute-MSI
Function Execute-MSI{
<#
.SYNOPSIS
	Executes msiexec.exe to perform the following actions for MSI & MSP files and MSI product codes: install, uninstall, patch, repair, active setup.
.DESCRIPTION
	Executes msiexec.exe to perform the following actions for MSI & MSP files and MSI product codes: install, uninstall, patch, repair, active setup.
	If the -Action parameter is set to "Install" and the MSI is already installed, the function will exit.
	Sets default switches to be passed to msiexec based on the preferences in the XML configuration file.
	Automatically generates a log file name and creates a verbose log file for all msiexec operations.
	Expects the MSI or MSP file to be located in the "Files" sub directory of the App Deploy Toolkit. Expects transform files to be in the same directory as the MSI file.
.DEPENDENCIES
	Get-InstalledApplication
	Get-MsiTableProperty
	Execute-Process
.PARAMETER Action
	The action to perform. Options: Install, Uninstall, Patch, Repair, ActiveSetup.
.PARAMETER Path
	The path to the MSI/MSP file or the product code of the installed MSI.
.PARAMETER Transform
	The name of the transform file(s) to be applied to the MSI. The transform file is expected to be in the same directory as the MSI file.
.PARAMETER Patch
	The name of the patch (msp) file(s) to be applied to the MSI for use with the "Install" action. The patch file is expected to be in the same directory as the MSI file.
.PARAMETER Parameters
	Overrides the default parameters specified in the XML configuration file. Install default is: "REBOOT=ReallySuppress /QB!". Uninstall default is: "REBOOT=ReallySuppress /QN".
.PARAMETER AddParameters
	Adds to the default parameters specified in the XML configuration file. Install default is: "REBOOT=ReallySuppress /QB!". Uninstall default is: "REBOOT=ReallySuppress /QN".
.PARAMETER SecureParameters
	Hides all parameters passed to the MSI or MSP file from the toolkit Log file.
.PARAMETER LoggingOptions
	Overrides the default logging options specified in the XML configuration file. Default options are: "/L*v".
.PARAMETER LogName
	Overrides the default log file name. The default log file name is generated from the MSI file name. If LogName does not end in .log, it will be automatically appended.
	For uninstallations, by default the product code is resolved to the DisplayName and version of the application.
.PARAMETER WorkingDirectory
	Overrides the working directory. The working directory is set to the location of the MSI file.
.PARAMETER SkipMSIAlreadyInstalledCheck
	Skips the check to determine if the MSI is already installed on the system. Default is: $false.
.PARAMETER IncludeUpdatesAndHotfixes
	Include matches against updates and hotfixes in results.
.PARAMETER PassThru
	Returns ExitCode, STDOut, and STDErr output from the process.
.PARAMETER ContinueOnError
	Continue if an exit code is returned by msiexec that is not recognized by the App Deploy Toolkit. Default is: $false.
.EXAMPLE
	Execute-MSI -Action 'Install' -Path 'Adobe_FlashPlayer_11.2.202.233_x64_EN.msi'
	Installs an MSI
.EXAMPLE
	Execute-MSI -Action 'Install' -Path 'Adobe_FlashPlayer_11.2.202.233_x64_EN.msi' -Transform 'Adobe_FlashPlayer_11.2.202.233_x64_EN_01.mst' -Parameters '/QN'
	Installs an MSI, applying a transform and overriding the default MSI toolkit parameters
.EXAMPLE
	[psobject]$ExecuteMSIResult = Execute-MSI -Action 'Install' -Path 'Adobe_FlashPlayer_11.2.202.233_x64_EN.msi' -PassThru
	Installs an MSI and stores the result of the execution into a variable by using the -PassThru option
.EXAMPLE
	Execute-MSI -Action 'Uninstall' -Path '{26923b43-4d38-484f-9b9e-de460746276c}'
	Uninstalls an MSI using a product code
.EXAMPLE
	Execute-MSI -Action 'Patch' -Path 'Adobe_Reader_11.0.3_EN.msp'
	Installs an MSP
.NOTES
.LINK
	http://psappdeploytoolkit.com
#>
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $false)]
		[ValidateSet('Install', 'Uninstall', 'Patch', 'Repair', 'ActiveSetup')]
		[string]$Action = 'Install',
		[Parameter(Mandatory = $true, HelpMessage = 'Please enter either the path to the MSI/MSP file or the ProductCode')]
		[ValidateScript({ ($_ -match $MSIProductCodeRegExPattern) -or ('.msi', '.msp' -contains [IO.Path]::GetExtension($_)) })]
		[Alias('FilePath')]
		[string]$Path,
		[Parameter(Mandatory = $false)]
		[ValidateNotNullorEmpty()]
		[string]$Transform,
		[Parameter(Mandatory = $false)]
		[Alias('Arguments')]
		[ValidateNotNullorEmpty()]
		[string]$Parameters,
		[Parameter(Mandatory = $false)]
		[ValidateNotNullorEmpty()]
		[string]$AddParameters,
		[Parameter(Mandatory = $false)]
		[ValidateNotNullorEmpty()]
		[switch]$SecureParameters = $false,
		[Parameter(Mandatory = $false)]
		[ValidateNotNullorEmpty()]
		[string]$Patch,
		[Parameter(Mandatory = $false)]
		[ValidateNotNullorEmpty()]
		[string]$LoggingOptions,
		[Parameter(Mandatory = $false)]
		[Alias('LogName')]
		[string]$private:LogName,
		[Parameter(Mandatory = $false)]
		[ValidateNotNullorEmpty()]
		[string]$WorkingDirectory,
		[Parameter(Mandatory = $false)]
		[ValidateNotNullorEmpty()]
		[switch]$SkipMSIAlreadyInstalledCheck = $false,
		[Parameter(Mandatory = $false)]
		[switch]$IncludeUpdatesAndHotfixes = $false,
		[Parameter(Mandatory = $false)]
		[ValidateNotNullorEmpty()]
		[switch]$PassThru = $false,
		[Parameter(Mandatory = $false)]
		[ValidateNotNullorEmpty()]
		[boolean]$ContinueOnError = $false
	)
	
	Begin
	{
		## Get the name of this function and write header
		[string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
		Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -CmdletBoundParameters $PSBoundParameters -Header
	}
	Process
	{
		## Initialize variable indicating whether $Path variable is a Product Code or not
		[boolean]$PathIsProductCode = $false
		
		## If the path matches a product code
		If ($Path -match $MSIProductCodeRegExPattern)
		{
			#  Set variable indicating that $Path variable is a Product Code
			[boolean]$PathIsProductCode = $true
			
			#  Resolve the product code to a publisher, application name, and version
			Write-Log -Message 'Resolve product code to a publisher, application name, and version.' -Source ${CmdletName}
			
			If ($IncludeUpdatesAndHotfixes)
			{
				[psobject]$productCodeNameVersion = Get-InstalledApplication -ProductCode $path -IncludeUpdatesAndHotfixes | Select-Object -Property 'Publisher', 'DisplayName', 'DisplayVersion' -First 1 -ErrorAction 'SilentlyContinue'
			}
			Else
			{
				[psobject]$productCodeNameVersion = Get-InstalledApplication -ProductCode $path | Select-Object -Property 'Publisher', 'DisplayName', 'DisplayVersion' -First 1 -ErrorAction 'SilentlyContinue'
			}
			
			#  Build the log file name
			If (-not $logName)
			{
				If ($productCodeNameVersion)
				{
					If ($productCodeNameVersion.Publisher)
					{
						$logName = ($productCodeNameVersion.Publisher + '_' + $productCodeNameVersion.DisplayName + '_' + $productCodeNameVersion.DisplayVersion) -replace "[$invalidFileNameChars]", '' -replace ' ', ''
					}
					Else
					{
						$logName = ($productCodeNameVersion.DisplayName + '_' + $productCodeNameVersion.DisplayVersion) -replace "[$invalidFileNameChars]", '' -replace ' ', ''
					}
				}
				Else
				{
					#  Out of other options, make the Product Code the name of the log file
					$logName = $Path
				}
			}
		}
		Else
		{
			#  Get the log file name without file extension
			If (-not $logName) { $logName = ([IO.FileInfo]$path).BaseName }
			ElseIf ('.log', '.txt' -contains [IO.Path]::GetExtension($logName)) { $logName = [IO.Path]::GetFileNameWithoutExtension($logName) }
		}
		
		If ($configToolkitCompressLogs)
		{
			## Build the log file path
			[string]$logPath = $logTempFolder
		}
		Else
		{
			## Create the Log directory if it doesn't already exist
			If (-not (Test-Path -LiteralPath $configMSILogDir -PathType 'Container' -ErrorAction 'SilentlyContinue'))
			{
				$null = New-Item -Path $configMSILogDir -ItemType 'Directory' -ErrorAction 'SilentlyContinue'
			}
			## Build the log file path
			[string]$logPath = $configMSILogDir
		}
		
		## Set the installation Parameters
		If ($deployModeSilent)
		{
			$msiInstallDefaultParams = $configMSISilentParams
			$msiUninstallDefaultParams = $configMSISilentParams
		}
		Else
		{
			$msiInstallDefaultParams = $configMSIInstallParams
			$msiUninstallDefaultParams = $configMSIUninstallParams
		}
		
		## Build the MSI Parameters
		Switch ($action)
		{
			'Install' { $option = '/i'; [string]$msiLogFile = "$logPath" + '\' + 'MSI_' + "$logName"; $msiDefaultParams = $msiInstallDefaultParams }
			'Uninstall' { $option = '/x'; [string]$msiLogFile = "$logPath" + '\' + 'MSI_UNINST_' + "$logName"; $msiDefaultParams = $msiUninstallDefaultParams }
			'Patch' { $option = '/update'; [string]$msiLogFile = "$logPath" + '\' + 'MSI_PATCH_' + "$logName"; $msiDefaultParams = $msiInstallDefaultParams }
			'Repair' { $option = '/f'; [string]$msiLogFile = "$logPath" + '\' + 'MSI_REPAIR_' + "$logName"; $msiDefaultParams = $msiInstallDefaultParams }
			'ActiveSetup' { $option = '/fups'; [string]$msiLogFile = "$logPath" + '\' + 'MSI_ACTIVESETUP_' + "$logName" }
		}
		
		## Append ".log" to the MSI logfile path and enclose in quotes
		If ([IO.Path]::GetExtension($msiLogFile) -ne '.log')
		{
			[string]$msiLogFile = $msiLogFile + '.log'
			[string]$msiLogFile = "`"$msiLogFile`""
		}
		
		## If the MSI is in the Files directory, set the full path to the MSI
		If (Test-Path -LiteralPath (Join-Path -Path $dirFiles -ChildPath $path -ErrorAction 'SilentlyContinue') -PathType 'Leaf' -ErrorAction 'SilentlyContinue')
		{
			[string]$msiFile = Join-Path -Path $dirFiles -ChildPath $path
		}
		ElseIf (Test-Path -LiteralPath $Path -ErrorAction 'SilentlyContinue')
		{
			[string]$msiFile = (Get-Item -LiteralPath $Path).FullName
		}
		ElseIf ($PathIsProductCode)
		{
			[string]$msiFile = $Path
		}
		Else
		{
			Write-Log -Message "Failed to find MSI file [$path]." -Severity 3 -Source ${CmdletName}
			If (-not $ContinueOnError)
			{
				Throw "Failed to find MSI file [$path]."
			}
			Continue
		}
		
		## Set the working directory of the MSI
		If ((-not $PathIsProductCode) -and (-not $workingDirectory)) { [string]$workingDirectory = Split-Path -Path $msiFile -Parent }
		
		## Enumerate all transforms specified, qualify the full path if possible and enclose in quotes
		If ($transform)
		{
			[string[]]$transforms = $transform -split ','
			0 .. ($transforms.Length - 1) | ForEach-Object {
				If (Test-Path -LiteralPath (Join-Path -Path (Split-Path -Path $msiFile -Parent) -ChildPath $transforms[$_]) -PathType 'Leaf')
				{
					$transforms[$_] = Join-Path -Path (Split-Path -Path $msiFile -Parent) -ChildPath $transforms[$_].Replace('.\', '')
				}
				Else
				{
					$transforms[$_] = $transforms[$_]
				}
			}
			[string]$mstFile = "`"$($transforms -join ';')`""
		}
		
		## Enumerate all patches specified, qualify the full path if possible and enclose in quotes
		If ($patch)
		{
			[string[]]$patches = $patch -split ','
			0 .. ($patches.Length - 1) | ForEach-Object {
				If (Test-Path -LiteralPath (Join-Path -Path (Split-Path -Path $msiFile -Parent) -ChildPath $patches[$_]) -PathType 'Leaf')
				{
					$patches[$_] = Join-Path -Path (Split-Path -Path $msiFile -Parent) -ChildPath $patches[$_].Replace('.\', '')
				}
				Else
				{
					$patches[$_] = $patches[$_]
				}
			}
			[string]$mspFile = "`"$($patches -join ';')`""
		}
		
		## Get the ProductCode of the MSI
		If ($PathIsProductCode)
		{
			[string]$MSIProductCode = $path
		}
		ElseIf ([IO.Path]::GetExtension($msiFile) -eq '.msi')
		{
			Try
			{
				[hashtable]$GetMsiTablePropertySplat = @{ Path = $msiFile; Table = 'Property'; ContinueOnError = $false }
				If ($transforms) { $GetMsiTablePropertySplat.Add('TransformPath', $transforms) }
				[string]$MSIProductCode = Get-MsiTableProperty @GetMsiTablePropertySplat | Select-Object -ExpandProperty 'ProductCode' -ErrorAction 'Stop'
			}
			Catch
			{
				Write-Log -Message "Failed to get the ProductCode from the MSI file. Continue with requested action [$Action]..." -Source ${CmdletName}
			}
		}
		
		## Enclose the MSI file in quotes to avoid issues with spaces when running msiexec
		[string]$msiFile = "`"$msiFile`""
		
		## Start building the MsiExec command line starting with the base action and file
		[string]$argsMSI = "$option $msiFile"
		#  Add MST
		If ($transform) { $argsMSI = "$argsMSI TRANSFORMS=$mstFile TRANSFORMSSECURE=1" }
		#  Add MSP
		If ($patch) { $argsMSI = "$argsMSI PATCH=$mspFile" }
		#  Replace default parameters if specified.
		If ($Parameters) { $argsMSI = "$argsMSI $Parameters" }
		Else { $argsMSI = "$argsMSI $msiDefaultParams" }
		#  Append parameters to default parameters if specified.
		If ($AddParameters) { $argsMSI = "$argsMSI $AddParameters" }
		#  Add custom Logging Options if specified, otherwise, add default Logging Options from Config file
		If ($LoggingOptions) { $argsMSI = "$argsMSI $LoggingOptions $msiLogFile" }
		Else { $argsMSI = "$argsMSI $configMSILoggingOptions $msiLogFile" }
		
		## Check if the MSI is already installed. If no valid ProductCode to check, then continue with requested MSI action.
		If ($MSIProductCode)
		{
			If ($SkipMSIAlreadyInstalledCheck)
			{
				[boolean]$IsMsiInstalled = $false
			}
			Else
			{
				If ($IncludeUpdatesAndHotfixes)
				{
					[psobject]$MsiInstalled = Get-InstalledApplication -ProductCode $MSIProductCode -IncludeUpdatesAndHotfixes
				}
				Else
				{
					[psobject]$MsiInstalled = Get-InstalledApplication -ProductCode $MSIProductCode
				}
				If ($MsiInstalled) { [boolean]$IsMsiInstalled = $true }
			}
		}
		Else
		{
			If ($Action -eq 'Install') { [boolean]$IsMsiInstalled = $false }
			Else { [boolean]$IsMsiInstalled = $true }
		}
		
		If (($IsMsiInstalled) -and ($Action -eq 'Install'))
		{
			Write-Log -Message "The MSI is already installed on this system. Skipping action [$Action]..." -Source ${CmdletName}
		}
		ElseIf (((-not $IsMsiInstalled) -and ($Action -eq 'Install')) -or ($IsMsiInstalled))
		{
			Write-Log -Message "Executing MSI action [$Action]..." -Source ${CmdletName}
			#  Build the hashtable with the options that will be passed to Execute-Process using splatting
			[hashtable]$ExecuteProcessSplat = @{
				Path	    = $exeMsiexec
				Parameters  = $argsMSI
				WindowStyle = 'Normal'
			}
			If ($WorkingDirectory) { $ExecuteProcessSplat.Add('WorkingDirectory', $WorkingDirectory) }
			If ($ContinueOnError) { $ExecuteProcessSplat.Add('ContinueOnError', $ContinueOnError) }
			If ($SecureParameters) { $ExecuteProcessSplat.Add('SecureParameters', $SecureParameters) }
			If ($PassThru) { $ExecuteProcessSplat.Add('PassThru', $PassThru) }
			#  Call the Execute-Process function
			If ($PassThru)
			{
				[psobject]$ExecuteResults = Execute-Process @ExecuteProcessSplat
			}
			Else
			{
				Execute-Process @ExecuteProcessSplat
			}
			#  Refresh environment variables for Windows Explorer process as Windows does not consistently update environment variables created by MSIs
			Update-Desktop
		}
		Else
		{
			Write-Log -Message "The MSI is not installed on this system. Skipping action [$Action]..." -Source ${CmdletName}
		}
	}
	End
	{
		If ($PassThru) { Write-Output -InputObject $ExecuteResults }
		Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -Footer
	}
}
#endregion

#region Function Get-InstalledApplication
Function Get-InstalledApplication{
<#
.SYNOPSIS
	Retrieves information about installed applications.
.DESCRIPTION
	Retrieves information about installed applications by querying the registry. You can specify an application name, a product code, or both.
	Returns information about application publisher, name & version, product code, uninstall string, install source, location, date, and application architecture.
.PARAMETER Name
	The name of the application to retrieve information for. Performs a contains match on the application display name by default.
.PARAMETER Exact
	Specifies that the named application must be matched using the exact name.
.PARAMETER WildCard
	Specifies that the named application must be matched using a wildcard search.
.PARAMETER RegEx
	Specifies that the named application must be matched using a regular expression search.
.PARAMETER ProductCode
	The product code of the application to retrieve information for.
.PARAMETER IncludeUpdatesAndHotfixes
	Include matches against updates and hotfixes in results.
.EXAMPLE
	Get-InstalledApplication -Name 'Adobe Flash'
.EXAMPLE
	Get-InstalledApplication -ProductCode '{1AD147D0-BE0E-3D6C-AC11-64F6DC4163F1}'
.NOTES
.LINK
	http://psappdeploytoolkit.com
#>
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $false)]
		[ValidateNotNullorEmpty()]
		[string[]]$Name,
		[Parameter(Mandatory = $false)]
		[switch]$Exact = $false,
		[Parameter(Mandatory = $false)]
		[switch]$WildCard = $false,
		[Parameter(Mandatory = $false)]
		[switch]$RegEx = $false,
		[Parameter(Mandatory = $false)]
		[ValidateNotNullorEmpty()]
		[string]$ProductCode,
		[Parameter(Mandatory = $false)]
		[switch]$IncludeUpdatesAndHotfixes
	)
	
	Begin
	{
		## Get the name of this function and write header
		[string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
		Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -CmdletBoundParameters $PSBoundParameters -Header
	}
	Process
	{
		If ($name)
		{
			Write-Log -Message "Get information for installed Application Name(s) [$($name -join ', ')]..." -Source ${CmdletName}
		}
		If ($productCode)
		{
			Write-Log -Message "Get information for installed Product Code [$ProductCode]..." -Source ${CmdletName}
		}
		
		## Enumerate the installed applications from the registry for applications that have the "DisplayName" property
		[psobject[]]$regKeyApplication = @()
		ForEach ($regKey in $regKeyApplications)
		{
			If (Test-Path -LiteralPath $regKey -ErrorAction 'SilentlyContinue' -ErrorVariable '+ErrorUninstallKeyPath')
			{
				[psobject[]]$UninstallKeyApps = Get-ChildItem -LiteralPath $regKey -ErrorAction 'SilentlyContinue' -ErrorVariable '+ErrorUninstallKeyPath'
				ForEach ($UninstallKeyApp in $UninstallKeyApps)
				{
					Try
					{
						[psobject]$regKeyApplicationProps = Get-ItemProperty -LiteralPath $UninstallKeyApp.PSPath -ErrorAction 'Stop'
						If ($regKeyApplicationProps.DisplayName) { [psobject[]]$regKeyApplication += $regKeyApplicationProps }
					}
					Catch
					{
						Write-Log -Message "Unable to enumerate properties from registry key path [$($UninstallKeyApp.PSPath)]. `n$(Resolve-Error)" -Severity 2 -Source ${CmdletName}
						Continue
					}
				}
			}
		}
		If ($ErrorUninstallKeyPath)
		{
			Write-Log -Message "The following error(s) took place while enumerating installed applications from the registry. `n$(Resolve-Error -ErrorRecord $ErrorUninstallKeyPath)" -Severity 2 -Source ${CmdletName}
		}
		
		## Create a custom object with the desired properties for the installed applications and sanitize property details
		[psobject[]]$installedApplication = @()
		ForEach ($regKeyApp in $regKeyApplication)
		{
			Try
			{
				[string]$appDisplayName = ''
				[string]$appDisplayVersion = ''
				[string]$appPublisher = ''
				
				## Bypass any updates or hotfixes
				If (-not $IncludeUpdatesAndHotfixes)
				{
					If ($regKeyApp.DisplayName -match '(?i)kb\d+') { Continue }
					If ($regKeyApp.DisplayName -match 'Cumulative Update') { Continue }
					If ($regKeyApp.DisplayName -match 'Security Update') { Continue }
					If ($regKeyApp.DisplayName -match 'Hotfix') { Continue }
				}
				
				## Remove any control characters which may interfere with logging and creating file path names from these variables
				$illegalChars = [string][System.IO.Path]::GetInvalidFileNameChars()
				$appDisplayName = $regKeyApp.DisplayName -replace $illegalChars, ''
				$appDisplayVersion = $regKeyApp.DisplayVersion -replace $illegalChars, ''
				$appPublisher = $regKeyApp.Publisher -replace $illegalChars, ''
				
				
				## Determine if application is a 64-bit application
				[boolean]$Is64BitApp = If (($is64Bit) -and ($regKeyApp.PSPath -notmatch '^Microsoft\.PowerShell\.Core\\Registry::HKEY_LOCAL_MACHINE\\SOFTWARE\\Wow6432Node')) { $true }
				Else { $false }
				
				If ($ProductCode)
				{
					## Verify if there is a match with the product code passed to the script
					If ($regKeyApp.PSChildName -match [regex]::Escape($productCode))
					{
						Write-Log -Message "Found installed application [$appDisplayName] version [$appDisplayVersion] matching product code [$productCode]." -Source ${CmdletName}
						$installedApplication += New-Object -TypeName 'PSObject' -Property @{
							UninstallSubkey = $regKeyApp.PSChildName
							ProductCode	    = If ($regKeyApp.PSChildName -match $MSIProductCodeRegExPattern) { $regKeyApp.PSChildName } Else { [string]::Empty }
							DisplayName	    = $appDisplayName
							DisplayVersion  = $appDisplayVersion
							UninstallString = $regKeyApp.UninstallString
							InstallSource   = $regKeyApp.InstallSource
							InstallLocation = $regKeyApp.InstallLocation
							InstallDate	    = $regKeyApp.InstallDate
							Publisher	    = $appPublisher
							Is64BitApplication = $Is64BitApp
						}
					}
				}
				
				If ($name)
				{
					## Verify if there is a match with the application name(s) passed to the script
					ForEach ($application in $Name)
					{
						$applicationMatched = $false
						If ($exact)
						{
							#  Check for an exact application name match
							If ($regKeyApp.DisplayName -eq $application)
							{
								$applicationMatched = $true
								Write-Log -Message "Found installed application [$appDisplayName] version [$appDisplayVersion] using exact name matching for search term [$application]." -Source ${CmdletName}
							}
						}
						ElseIf ($WildCard)
						{
							#  Check for wildcard application name match
							If ($regKeyApp.DisplayName -like $application)
							{
								$applicationMatched = $true
								Write-Log -Message "Found installed application [$appDisplayName] version [$appDisplayVersion] using wildcard matching for search term [$application]." -Source ${CmdletName}
							}
						}
						ElseIf ($RegEx)
						{
							#  Check for a regex application name match
							If ($regKeyApp.DisplayName -match $application)
							{
								$applicationMatched = $true
								Write-Log -Message "Found installed application [$appDisplayName] version [$appDisplayVersion] using regex matching for search term [$application]." -Source ${CmdletName}
							}
						}
						#  Check for a contains application name match
						ElseIf ($regKeyApp.DisplayName -match [regex]::Escape($application))
						{
							$applicationMatched = $true
							Write-Log -Message "Found installed application [$appDisplayName] version [$appDisplayVersion] using contains matching for search term [$application]." -Source ${CmdletName}
						}
						
						If ($applicationMatched)
						{
							$installedApplication += New-Object -TypeName 'PSObject' -Property @{
								UninstallSubkey = $regKeyApp.PSChildName
								ProductCode	    = If ($regKeyApp.PSChildName -match $MSIProductCodeRegExPattern) { $regKeyApp.PSChildName } Else { [string]::Empty }
								DisplayName	    = $appDisplayName
								DisplayVersion  = $appDisplayVersion
								UninstallString = $regKeyApp.UninstallString
								InstallSource   = $regKeyApp.InstallSource
								InstallLocation = $regKeyApp.InstallLocation
								InstallDate	    = $regKeyApp.InstallDate
								Publisher	    = $appPublisher
								Is64BitApplication = $Is64BitApp
							}
						}
					}
				}
			}
			Catch
			{
				Write-Log -Message "Failed to resolve application details from registry for [$appDisplayName]. `n$(Resolve-Error)" -Severity 3 -Source ${CmdletName}
				Continue
			}
		}
		
		Write-Output -InputObject $installedApplication
	}
	End
	{
		Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -Footer
	}
}
#endregion

#region Function Test-IsMutexAvailable
Function Test-IsMutexAvailable
{
<#
.SYNOPSIS
	Wait, up to a timeout value, to check if current thread is able to acquire an exclusive lock on a system mutex.
.DESCRIPTION
	A mutex can be used to serialize applications and prevent multiple instances from being opened at the same time.
	Wait, up to a timeout (default is 1 millisecond), for the mutex to become available for an exclusive lock.
.PARAMETER MutexName
	The name of the system mutex.
.PARAMETER MutexWaitTime
	The number of milliseconds the current thread should wait to acquire an exclusive lock of a named mutex. Default is: 1 millisecond.
	A wait time of -1 milliseconds means to wait indefinitely. A wait time of zero does not acquire an exclusive lock but instead tests the state of the wait handle and returns immediately.
.EXAMPLE
	Test-IsMutexAvailable -MutexName 'Global\_MSIExecute' -MutexWaitTimeInMilliseconds 500
.EXAMPLE
	Test-IsMutexAvailable -MutexName 'Global\_MSIExecute' -MutexWaitTimeInMilliseconds (New-TimeSpan -Minutes 5).TotalMilliseconds
.EXAMPLE
	Test-IsMutexAvailable -MutexName 'Global\_MSIExecute' -MutexWaitTimeInMilliseconds (New-TimeSpan -Seconds 60).TotalMilliseconds
.NOTES
	This is an internal script function and should typically not be called directly.
.LINK
	http://msdn.microsoft.com/en-us/library/aa372909(VS.85).asp
	http://psappdeploytoolkit.com
#>
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $true)]
		[ValidateLength(1, 260)]
		[string]$MutexName,
		[Parameter(Mandatory = $false)]
		[ValidateScript({ ($_ -ge -1) -and ($_ -le [int32]::MaxValue) })]
		[int32]$MutexWaitTimeInMilliseconds = 1
	)
	
	Begin
	{
		## Get the name of this function and write header
		[string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
		Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -CmdletBoundParameters $PSBoundParameters -Header
		
		## Initialize Variables
		[timespan]$MutexWaitTime = [timespan]::FromMilliseconds($MutexWaitTimeInMilliseconds)
		If ($MutexWaitTime.TotalMinutes -ge 1)
		{
			[string]$WaitLogMsg = "$($MutexWaitTime.TotalMinutes) minute(s)"
		}
		ElseIf ($MutexWaitTime.TotalSeconds -ge 1)
		{
			[string]$WaitLogMsg = "$($MutexWaitTime.TotalSeconds) second(s)"
		}
		Else
		{
			[string]$WaitLogMsg = "$($MutexWaitTime.Milliseconds) millisecond(s)"
		}
		[boolean]$IsUnhandledException = $false
		[boolean]$IsMutexFree = $false
		[Threading.Mutex]$OpenExistingMutex = $null
	}
	Process
	{
		Write-Log -Message "Check to see if mutex [$MutexName] is available. Wait up to [$WaitLogMsg] for the mutex to become available." -Source ${CmdletName}
		Try
		{
			## Using this variable allows capture of exceptions from .NET methods. Private scope only changes value for current function.
			$private:previousErrorActionPreference = $ErrorActionPreference
			$ErrorActionPreference = 'Stop'
			
			## Open the specified named mutex, if it already exists, without acquiring an exclusive lock on it. If the system mutex does not exist, this method throws an exception instead of creating the system object.
			[Threading.Mutex]$OpenExistingMutex = [Threading.Mutex]::OpenExisting($MutexName)
			## Attempt to acquire an exclusive lock on the mutex. Use a Timespan to specify a timeout value after which no further attempt is made to acquire a lock on the mutex.
			$IsMutexFree = $OpenExistingMutex.WaitOne($MutexWaitTime, $false)
		}
		Catch [Threading.WaitHandleCannotBeOpenedException] {
			## The named mutex does not exist
			$IsMutexFree = $true
		}
		Catch [ObjectDisposedException] {
			## Mutex was disposed between opening it and attempting to wait on it
			$IsMutexFree = $true
		}
		Catch [UnauthorizedAccessException] {
			## The named mutex exists, but the user does not have the security access required to use it
			$IsMutexFree = $false
		}
		Catch [Threading.AbandonedMutexException] {
			## The wait completed because a thread exited without releasing a mutex. This exception is thrown when one thread acquires a mutex object that another thread has abandoned by exiting without releasing it.
			$IsMutexFree = $true
		}
		Catch
		{
			$IsUnhandledException = $true
			## Return $true, to signify that mutex is available, because function was unable to successfully complete a check due to an unhandled exception. Default is to err on the side of the mutex being available on a hard failure.
			Write-Log -Message "Unable to check if mutex [$MutexName] is available due to an unhandled exception. Will default to return value of [$true]. `n$(Resolve-Error)" -Severity 3 -Source ${CmdletName}
			$IsMutexFree = $true
		}
		Finally
		{
			If ($IsMutexFree)
			{
				If (-not $IsUnhandledException)
				{
					Write-Log -Message "Mutex [$MutexName] is available for an exclusive lock." -Source ${CmdletName}
				}
			}
			Else
			{
				If ($MutexName -eq 'Global\_MSIExecute')
				{
					## Get the command line for the MSI installation in progress
					Try
					{
						[string]$msiInProgressCmdLine = Get-WmiObject -Class 'Win32_Process' -Filter "name = 'msiexec.exe'" -ErrorAction 'Stop' | Where-Object { $_.CommandLine } | Select-Object -ExpandProperty 'CommandLine' | Where-Object { $_ -match '\.msi' } | ForEach-Object { $_.Trim() }
					}
					Catch { }
					Write-Log -Message "Mutex [$MutexName] is not available for an exclusive lock because the following MSI installation is in progress [$msiInProgressCmdLine]." -Severity 2 -Source ${CmdletName}
				}
				Else
				{
					Write-Log -Message "Mutex [$MutexName] is not available because another thread already has an exclusive lock on it." -Source ${CmdletName}
				}
			}
			
			If (($null -ne $OpenExistingMutex) -and ($IsMutexFree))
			{
				## Release exclusive lock on the mutex
				$null = $OpenExistingMutex.ReleaseMutex()
				$OpenExistingMutex.Close()
			}
			If ($private:previousErrorActionPreference) { $ErrorActionPreference = $private:previousErrorActionPreference }
		}
	}
	End
	{
		Write-Output -InputObject $IsMutexFree
		
		Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -Footer
	}
}
#endregion

#region Function Exit-Script
Function Exit-Script
{
<#
.SYNOPSIS
	Exit the script, perform cleanup actions, and pass an exit code to the parent process.
.DESCRIPTION
	Always use when exiting the script to ensure cleanup actions are performed.
.PARAMETER ExitCode
	The exit code to be passed from the script to the parent process, e.g. SCCM
.EXAMPLE
	Exit-Script -ExitCode 0
.EXAMPLE
	Exit-Script -ExitCode 1618
.NOTES
.LINK
	http://psappdeploytoolkit.com
#>
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $false)]
		[ValidateNotNullorEmpty()]
		[int32]$ExitCode = 0
	)
	
	## Get the name of this function
	[string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
	
	## Stop the Close Program Dialog if running
	If ($formCloseApps) { $formCloseApps.Close }
	
	## Close the Installation Progress Dialog if running
	Stop-Process -Name "EUSInstallProgress" -Force -ErrorAction SilentlyContinue
	
	## Clean up cache content if exist
	if (Test-Path -Path "$configToolkitCachePath\$installName")	{ Remove-ContentFromCache }
	
	## If block execution variable is true, call the function to unblock execution
	If ($BlockExecution) { Unblock-AppExecution }
	
	## If Terminal Server mode was set, turn it off
	If ($terminalServerMode) { Disable-TerminalServerInstallMode }
	
	## Determine action based on exit code
	Switch ($exitCode)
	{
		$configInstallationUIExitCode { $installSuccess = $false }
		$configInstallationDeferExitCode { $installSuccess = $false }
		3010 { $installSuccess = $true }
		1641 { $installSuccess = $true }
		0 { $installSuccess = $true }
		Default { $installSuccess = $false }
	}
	
	## Determine if balloon notification should be shown
	If ($deployModeSilent) { [boolean]$configShowBalloonNotifications = $false }
	
	If ($installSuccess)
	{
		If (Test-Path -LiteralPath $regKeyDeferHistory -ErrorAction 'SilentlyContinue')
		{
			Write-Log -Message 'Remove deferral history...' -Source ${CmdletName}
			Remove-RegistryKey -Key $regKeyDeferHistory -Recurse
		}
		
		[string]$balloonText = "$deploymentTypeName $configBalloonTextComplete"
		## Handle reboot prompts on successful script completion
		If (($AllowRebootPassThru) -and ((($msiRebootDetected) -or ($exitCode -eq 3010)) -or ($exitCode -eq 1641)))
		{
			Write-Log -Message 'A restart has been flagged as required.' -Source ${CmdletName}
			[string]$balloonText = "$deploymentTypeName $configBalloonTextRestartRequired"
			If (($msiRebootDetected) -and ($exitCode -ne 1641)) { [int32]$exitCode = 3010 }
		}
		Else
		{
			[int32]$exitCode = 0
		}
		
		Write-Log -Message "$installName $deploymentTypeName completed with exit code [$exitcode]." -Source ${CmdletName}
		If ($configShowBalloonNotifications) { Show-BalloonTip -BalloonTipIcon 'Info' -BalloonTipText $balloonText }
	}
	ElseIf (-not $installSuccess)
	{
		Write-Log -Message "$installName $deploymentTypeName completed with exit code [$exitcode]." -Source ${CmdletName}
		If (($exitCode -eq $configInstallationUIExitCode) -or ($exitCode -eq $configInstallationDeferExitCode))
		{
			[string]$balloonText = "$deploymentTypeName $configBalloonTextFastRetry"
			If ($configShowBalloonNotifications) { Show-BalloonTip -BalloonTipIcon 'Warning' -BalloonTipText $balloonText }
		}
		Else
		{
			[string]$balloonText = "$deploymentTypeName $configBalloonTextError"
			If ($configShowBalloonNotifications) { Show-BalloonTip -BalloonTipIcon 'Error' -BalloonTipText $balloonText }
		}
	}
	
	[string]$LogDash = '-' * 79
	Write-Log -Message $LogDash -Source ${CmdletName}
	
	## Archive the log files to zip format and then delete the temporary logs folder
	If ($configToolkitCompressLogs)
	{
		## Disable logging to file so that we can archive the log files
		. $DisableScriptLogging
		
		[string]$DestinationArchiveFileName = $installName + '_' + $deploymentType + '_' + ((Get-Date -Format 'yyyy-MM-dd-hh-mm-ss').ToString()) + '.zip'
		New-ZipFile -DestinationArchiveDirectoryPath $configToolkitLogDir -DestinationArchiveFileName $DestinationArchiveFileName -SourceDirectory $logTempFolder -RemoveSourceAfterArchiving
	}
	
	If ($script:notifyIcon)
	{
		Try { $script:notifyIcon.Dispose() }
		Catch { }
	}
	#Release mutex lock on PSADT wrapper
	if ($mtx)
	{
		$mtx.ReleaseMutex()
		$mtx.Dispose()
	}
	## Exit the script, returning the exit code to SCCM
	If (Test-Path -LiteralPath 'variable:HostInvocation') { $script:ExitCode = $exitCode; Exit }
	Else { Exit $exitCode }
}
#endregion

#region Function Close-InstallationProgress
Function Close-InstallationProgress
{
<#
.SYNOPSIS
	Closes the dialog created by Show-InstallationProgress.
.DESCRIPTION
	Closes the dialog created by Show-InstallationProgress.
	This function is called by the Exit-Script function to close a running instance of the progress dialog if found.
.DEPENDENCIES
	
.EXAMPLE
	Close-InstallationProgress
.NOTES
	This is an internal script function and should typically not be called directly.
.LINK
	http://psappdeploytoolkit.com
#>
	[CmdletBinding()]
	Param (
	)
	
	Begin
	{
		## Get the name of this function and write header
		[string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
		Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -CmdletBoundParameters $PSBoundParameters -Header
	}
	Process
	{
		If ($script:ProgressSyncHash.Window.Dispatcher.Thread.ThreadState -eq 'Running')
		{
			## Close the progress thread
			Write-Log -Message 'Close the installation progress dialog.' -Source ${CmdletName}
			$script:ProgressSyncHash.Window.Dispatcher.InvokeShutdown()
			$script:ProgressSyncHash.Clear()
			$script:ProgressRunspace.Close()
		}
	}
	End
	{
		Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -Footer
	}
}
#endregion

#region Function Block-AppExecution
Function Block-AppExecution
{
<#
.SYNOPSIS
	Block the execution of an application(s)
.DESCRIPTION
	This function is called when you pass the -BlockExecution parameter to the Stop-RunningApplications function. It does the following:
	1. Makes a copy of this script in a temporary directory on the local machine.
	2. Checks for an existing scheduled task from previous failed installation attempt where apps were blocked and if found, calls the Unblock-AppExecution function to restore the original IFEO registry keys.
	   This is to prevent the function from overriding the backup of the original IFEO options.
	3. Creates a scheduled task to restore the IFEO registry key values in case the script is terminated uncleanly by calling the local temporary copy of this script with the parameter -CleanupBlockedApps.
	4. Modifies the "Image File Execution Options" registry key for the specified process(s) to call this script with the parameter -ShowBlockedAppDialog.
	5. When the script is called with those parameters, it will display a custom message to the user to indicate that execution of the application has been blocked while the installation is in progress.
	   The text of this message can be customized in the XML configuration file.
.PARAMETER ProcessName
	Name of the process or processes separated by commas
.EXAMPLE
	Block-AppExecution -ProcessName ('winword','excel')
.NOTES
	This is an internal script function and should typically not be called directly.
	It is used when the -BlockExecution parameter is specified with the Show-InstallationWelcome function to block applications.
.LINK
	http://psappdeploytoolkit.com
#>
	[CmdletBinding()]
	Param (
		## Specify process names separated by commas
		[Parameter(Mandatory = $true)]
		[ValidateNotNullorEmpty()]
		[string[]]$ProcessName
	)
	
	Begin
	{
		## Get the name of this function and write header
		[string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
		Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -CmdletBoundParameters $PSBoundParameters -Header
		
		## Remove illegal characters from the scheduled task arguments string
		[char[]]$invalidScheduledTaskChars = '$', '!', '''', '"', '(', ')', ';', '\', '`', '*', '?', '{', '}', '[', ']', '<', '>', '|', '&', '%', '#', '~', '@', ' '
		[string]$SchInstallName = $installName
		ForEach ($invalidChar in $invalidScheduledTaskChars) { [string]$SchInstallName = $SchInstallName -replace [regex]::Escape($invalidChar), '' }
		[string]$schTaskUnblockAppsCommand += "-ExecutionPolicy Bypass -NoProfile -NoLogo -WindowStyle Hidden -File `"$dirAppDeployTemp\$scriptFileName`" -CleanupBlockedApps -ReferredInstallName `"$SchInstallName`" -ReferredInstallTitle `"$installTitle`" -ReferredLogName `"$logName`" -AsyncToolkitLaunch"
		## Specify the scheduled task configuration in XML format
		[string]$xmlUnblockAppsSchTask = @"
<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.2" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
	<RegistrationInfo></RegistrationInfo>
	<Triggers>
		<BootTrigger>
			<Enabled>true</Enabled>
		</BootTrigger>
	</Triggers>
	<Principals>
		<Principal id="Author">
			<UserId>S-1-5-18</UserId>
		</Principal>
	</Principals>
	<Settings>
		<MultipleInstancesPolicy>IgnoreNew</MultipleInstancesPolicy>
		<DisallowStartIfOnBatteries>false</DisallowStartIfOnBatteries>
		<StopIfGoingOnBatteries>false</StopIfGoingOnBatteries>
		<AllowHardTerminate>true</AllowHardTerminate>
		<StartWhenAvailable>false</StartWhenAvailable>
		<RunOnlyIfNetworkAvailable>false</RunOnlyIfNetworkAvailable>
		<IdleSettings>
			<StopOnIdleEnd>false</StopOnIdleEnd>
			<RestartOnIdle>false</RestartOnIdle>
		</IdleSettings>
		<AllowStartOnDemand>true</AllowStartOnDemand>
		<Enabled>true</Enabled>
		<Hidden>false</Hidden>
		<RunOnlyIfIdle>false</RunOnlyIfIdle>
		<WakeToRun>false</WakeToRun>
		<ExecutionTimeLimit>PT1H</ExecutionTimeLimit>
		<Priority>7</Priority>
	</Settings>
	<Actions Context="Author">
		<Exec>
			<Command>powershell.exe</Command>
			<Arguments>$schTaskUnblockAppsCommand</Arguments>
		</Exec>
	</Actions>
</Task>
"@
	}
	Process
	{
		## Bypass if in NonInteractive mode
		If ($deployModeNonInteractive)
		{
			Write-Log -Message "Bypassing Function [${CmdletName}] [Mode: $deployMode]." -Source ${CmdletName}
			Return
		}
		
		[string]$schTaskBlockedAppsName = $installName + '_BlockedApps'
		
		## Delete this file if it exists as it can cause failures (it is a bug from an older version of the toolkit)
		If (Test-Path -LiteralPath "$configToolkitTempPath\PSAppDeployToolkit" -PathType 'Leaf' -ErrorAction 'SilentlyContinue')
		{
			$null = Remove-Item -LiteralPath "$configToolkitTempPath\PSAppDeployToolkit" -Force -ErrorAction 'SilentlyContinue'
		}
		## Create Temporary directory (if required) and copy Toolkit so it can be called by scheduled task later if required
		If (-not (Test-Path -LiteralPath $dirAppDeployTemp -PathType 'Container' -ErrorAction 'SilentlyContinue'))
		{
			$null = New-Item -Path $dirAppDeployTemp -ItemType 'Directory' -ErrorAction 'SilentlyContinue'
		}
		
		Copy-Item -Path "$scriptRoot\*.*" -Destination $dirAppDeployTemp -Exclude 'thumbs.db' -Force -Recurse -ErrorAction 'SilentlyContinue'
		
		## Build the debugger block value script
		[string]$debuggerBlockMessageCmd = "`"powershell.exe -ExecutionPolicy Bypass -NoProfile -NoLogo -WindowStyle Hidden -File `" & chr(34) & `"$dirAppDeployTemp\$scriptFileName`" & chr(34) & `" -ShowBlockedAppDialog -AsyncToolkitLaunch -ReferredInstallTitle `" & chr(34) & `"$installTitle`" & chr(34)"
		[string[]]$debuggerBlockScript = "strCommand = $debuggerBlockMessageCmd"
		$debuggerBlockScript += 'set oWShell = CreateObject("WScript.Shell")'
		$debuggerBlockScript += 'oWShell.Run strCommand, 0, false'
		$debuggerBlockScript | Out-File -FilePath "$dirAppDeployTemp\AppDeployToolkit_BlockAppExecutionMessage.vbs" -Force -Encoding 'default' -ErrorAction 'SilentlyContinue'
		[string]$debuggerBlockValue = "wscript.exe `"$dirAppDeployTemp\AppDeployToolkit_BlockAppExecutionMessage.vbs`""
		
		## Create a scheduled task to run on startup to call this script and clean up blocked applications in case the installation is interrupted, e.g. user shuts down during installation"
		Write-Log -Message 'Create scheduled task to cleanup blocked applications in case installation is interrupted.' -Source ${CmdletName}
		If (Get-ScheduledTask -ContinueOnError $true | Select-Object -Property 'TaskName' | Where-Object { $_.TaskName -eq "\$schTaskBlockedAppsName" })
		{
			Write-Log -Message "Scheduled task [$schTaskBlockedAppsName] already exists." -Source ${CmdletName}
		}
		Else
		{
			## Export the scheduled task XML to file
			Try
			{
				#  Specify the filename to export the XML to
				[string]$xmlSchTaskFilePath = "$dirAppDeployTemp\SchTaskUnBlockApps.xml"
				[string]$xmlUnblockAppsSchTask | Out-File -FilePath $xmlSchTaskFilePath -Force -ErrorAction 'Stop'
			}
			Catch
			{
				Write-Log -Message "Failed to export the scheduled task XML file [$xmlSchTaskFilePath]. `n$(Resolve-Error)" -Severity 3 -Source ${CmdletName}
				Return
			}
			
			## Import the Scheduled Task XML file to create the Scheduled Task
			[psobject]$schTaskResult = Execute-Process -Path $exeSchTasks -Parameters "/create /f /tn $schTaskBlockedAppsName /xml `"$xmlSchTaskFilePath`"" -WindowStyle 'Hidden' -CreateNoWindow -PassThru
			If ($schTaskResult.ExitCode -ne 0)
			{
				Write-Log -Message "Failed to create the scheduled task [$schTaskBlockedAppsName] by importing the scheduled task XML file [$xmlSchTaskFilePath]." -Severity 3 -Source ${CmdletName}
				Return
			}
		}
		
		[string[]]$blockProcessName = $processName
		## Append .exe to match registry keys
		[string[]]$blockProcessName = $blockProcessName | ForEach-Object { $_ + '.exe' } -ErrorAction 'SilentlyContinue'
		
		## Enumerate each process and set the debugger value to block application execution
		ForEach ($blockProcess in $blockProcessName)
		{
			Write-Log -Message "Set the Image File Execution Option registry key to block execution of [$blockProcess]." -Source ${CmdletName}
			Set-RegistryKey -Key (Join-Path -Path $regKeyAppExecution -ChildPath $blockProcess) -Name 'Debugger' -Value $debuggerBlockValue -ContinueOnError $true
		}
	}
	End
	{
		Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -Footer
	}
}
#endregion

#region Function Copy-File
Function Copy-File
{
    <#
.SYNOPSIS

Copy a file or group of files to a destination path.

.DESCRIPTION

Copy a file or group of files to a destination path.

.PARAMETER Path

Path of the file to copy. Multiple paths can be specified

.PARAMETER Destination

Destination Path of the file to copy.

.PARAMETER Recurse

Copy files in subdirectories.

.PARAMETER Flatten

Flattens the files into the root destination directory.

.PARAMETER ContinueOnError

Continue if an error is encountered. This will continue the deployment script, but will not continue copying files if an error is encountered. Default is: $true.

.PARAMETER ContinueFileCopyOnError

Continue copying files if an error is encountered. This will continue the deployment script and will warn about files that failed to be copied. Default is: $false.

.PARAMETER UseRobocopy

Use Robocopy to copy files rather than native PowerShell method. Robocopy overcomes the 260 character limit. Supports * in file names, but not folders, in source paths. Default is configured in the AppDeployToolkitConfig.xml file: $true

.PARAMETER RobocopyParams

Override the default Robocopy parameters. Default is: /NJH /NJS /NS /NC /NP /NDL /FP /IS /IT /IM /XX /MT:4 /R:1 /W:1

.PARAMETER RobocopyAdditionalParams

Append to the default Robocopy parameters. Default is: /NJH /NJS /NS /NC /NP /NDL /FP /IS /IT /IM /XX /MT:4 /R:1 /W:1

.INPUTS

None

You cannot pipe objects to this function.

.OUTPUTS

None

This function does not generate any output.

.EXAMPLE

Copy-File -Path "$dirSupportFiles\MyApp.ini" -Destination "$envWinDir\MyApp.ini"

.EXAMPLE

Copy-File -Path "$dirSupportFiles\*.*" -Destination "$envTemp\tempfiles"

Copy all of the files in a folder to a destination folder.

.NOTES

.LINK

https://psappdeploytoolkit.com
#>
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $true, Position = 0)]
		[ValidateNotNullorEmpty()]
		[String[]]$Path,
		[Parameter(Mandatory = $true, Position = 1)]
		[ValidateNotNullorEmpty()]
		[String]$Destination,
		[Parameter(Mandatory = $false)]
		[Switch]$Recurse = $false,
		[Parameter(Mandatory = $false)]
		[Switch]$Flatten,
		[Parameter(Mandatory = $false)]
		[ValidateNotNullOrEmpty()]
		[Boolean]$ContinueOnError = $true,
		[Parameter(Mandatory = $false)]
		[ValidateNotNullOrEmpty()]
		[Boolean]$ContinueFileCopyOnError = $false,
		[Parameter(Mandatory = $false)]
		[ValidateNotNullOrEmpty()]
		[Boolean]$UseRobocopy = $configToolkitUseRobocopy,
		[Parameter(Mandatory = $false)]
		[ValidateNotNullOrEmpty()]
		[String]$RobocopyParams = '/NJH /NJS /NS /NC /NP /NDL /FP /IS /IT /IM /XX /MT:4 /R:1 /W:1',
		[String]$RobocopyAdditionalParams
	)
	
	Begin
	{
		## Get the name of this function and write header
		[String]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
		Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -CmdletBoundParameters $PSBoundParameters -Header
		
		# Check if Robocopy is on the system
		If ($UseRobocopy)
		{
			If (Test-Path -Path "$env:SystemRoot\System32\Robocopy.exe" -PathType Leaf)
			{
				$RobocopyCommand = "$env:SystemRoot\System32\Robocopy.exe"
			}
			Else
			{
				$UseRobocopy = $false
				Write-Log "Robocopy is not available on this system. Falling back to native PowerShell method." -Source ${CmdletName} -Severity 2
			}
		}
		Else
		{
			$UseRobocopy = $false
		}
	}
	Process
	{
		Foreach ($srcPath in $Path)
		{
			$UseRobocopyThis = $UseRobocopy
			If ($UseRobocopyThis)
			{
				Try
				{
					# Disable Robocopy if $Path has a folder containing a * wildcard
					If ($srcPath -match '\*.*\\')
					{
						$UseRobocopyThis = $false
						Write-Log "Asterisk wildcard specified in folder portion of path variable. Falling back to native PowerShell method." -Source ${CmdletName} -Severity 2
					}
					# Don't just check for an extension here, also check for base name without extension to allow copying to a directory such as .config
					If ([IO.Path]::HasExtension($Destination) -and [IO.Path]::GetFileNameWithoutExtension($Destination) -and -not (Test-Path -LiteralPath $Destination -PathType Container))
					{
						$UseRobocopyThis = $false
						Write-Log "Destination path appears to be a file. Falling back to native PowerShell method." -Source ${CmdletName} -Severity 2
						
					}
					If ($UseRobocopyThis)
					{
						
						# Pre-create destination folder if it does not exist; Robocopy will auto-create non-existent destination folders, but pre-creating ensures we can use Resolve-Path
						If (-not (Test-Path -LiteralPath $Destination -PathType Container))
						{
							Write-Log -Message "Destination assumed to be a folder which does not exist, creating destination folder [$Destination]." -Source ${CmdletName}
							$null = New-Item -Path $Destination -Type 'Directory' -Force -ErrorAction 'Stop'
						}
						If (Test-Path -LiteralPath $srcPath -PathType Container)
						{
							# If source exists as a folder, append the last subfolder to the destination, so that Robocopy produces similar results to native Powershell
							# Trim ending backslash from paths which can cause problems with Robocopy
							# Resolve paths in case relative paths beggining with .\, ..\, or \ are used
							$RobocopySource = (Resolve-Path -LiteralPath $srcPath.TrimEnd('\')).Path
							$RobocopyDestination = Join-Path (Resolve-Path -LiteralPath $Destination).Path (Split-Path -Path $srcPath -Leaf)
							$RobocopyFile = '*'
						}
						Else
						{
							# Else assume source is a file and split args to the format <SourceFolder> <DestinationFolder> <FileName>
							# Trim ending backslash from paths which can cause problems with Robocopy
							# Resolve paths in case relative paths beggining with .\, ..\, or \ are used
							$RobocopySource = (Resolve-Path -LiteralPath (Split-Path -Path $srcPath -Parent)).Path
							$RobocopyDestination = (Resolve-Path -LiteralPath $Destination.TrimEnd('\')).Path
							$RobocopyFile = (Split-Path -Path $srcPath -Leaf)
						}
						If ($Flatten)
						{
							Write-Log -Message "Copying file(s) recursively in path [$srcPath] to destination [$Destination] root folder, flattened." -Source ${CmdletName}
							[Hashtable]$CopyFileSplat = @{
								Path = (Join-Path $RobocopySource $RobocopyFile) # This will ensure that the source dir will have \* appended if it was a folder (which prevents creation of a folder at the destination), or keeps the original file name if it was a file
								Destination = $Destination # Use the original destination path, not $RobocopyDestination which could have had a subfolder appended to it
								Recurse = $false # Disable recursion as this will create subfolders in the destination
								Flatten = $false # Disable flattening to prevent infinite loops
								ContinueOnError = $ContinueOnError
								ContinueFileCopyOnError = $ContinueFileCopyOnError
								UseRobocopy = $UseRobocopy
								RobocopyParams = $RobocopyParams
								RobocopyAdditionalParams = $RobocopyAdditionalParams
							}
							# Copy all files from the root source folder
							Copy-File @CopyFileSplat
							# Copy all files from subfolders
							Get-ChildItem -Path $RobocopySource -Directory -Recurse -Force -ErrorAction 'SilentlyContinue' | ForEach-Object {
								# Append file name to subfolder path and repeat Copy-File
								$CopyFileSplat.Path = Join-Path $_.FullName $RobocopyFile
								Copy-File @CopyFileSplat
							}
							# Skip to next $SrcPath in $Path since we have handed off all copy tasks to separate executions of the function
							Continue
						}
						If ($Recurse)
						{
							# Add /E to Robocopy parameters if it is not already included
							if ($RobocopyParams -notmatch '/E(\s|$)' -and $RobocopyAdditionalParams -notmatch '/E(\s|$)')
							{
								$RobocopyParams = $RobocopyParams + " /E"
							}
							Write-Log -Message "Copying file(s) recursively in path [$srcPath] to destination [$Destination]." -Source ${CmdletName}
						}
						Else
						{
							# Ensure that /E is not included in the Robocopy parameters as it will copy recursive folders
							$RobocopyParams = $RobocopyParams -replace '/E(\s|$)'
							$RobocopyAdditionalParams = $RobocopyAdditionalParams -replace '/E(\s|$)'
							Write-Log -Message "Copying file(s) in path [$srcPath] to destination [$Destination]." -Source ${CmdletName}
						}
						
						$RobocopyArgs = "$RobocopyParams $RobocopyAdditionalParams `"$RobocopySource`" `"$RobocopyDestination`" `"$RobocopyFile`""
						Write-Log -Message "Executing Robocopy command: $RobocopyCommand $RobocopyArgs" -Source ${CmdletName}
						$RobocopyResult = Execute-Process -Path $RobocopyCommand -Parameters $RobocopyArgs -CreateNoWindow -ContinueOnError $true -Passthru -IgnoreExitCodes '0,1,2,3,4,5,6,7,8'
						# Trim the leading whitespace from each line of Robocopy output, ignore the last empty line, and join the lines back together
						$RobocopyOutput = ($RobocopyResult.StdOut.Split("`n").TrimStart() | Select-Object -SkipLast 1) -join "`n"
						Write-Log -Message "Robocopy output:`n$RobocopyOutput" -Source ${CmdletName}
						
						Switch ($RobocopyResult.ExitCode)
						{
							0 { Write-Log -Message "Robocopy completed. No files were copied. No failure was encountered. No files were mismatched. The files already exist in the destination directory; therefore, the copy operation was skipped." -Source ${CmdletName} }
							1 { Write-Log -Message "Robocopy completed. All files were copied successfully." -Source ${CmdletName} }
							2 { Write-Log -Message "Robocopy completed. There are some additional files in the destination directory that aren't present in the source directory. No files were copied." -Source ${CmdletName} }
							3 { Write-Log -Message "Robocopy completed. Some files were copied. Additional files were present. No failure was encountered." -Source ${CmdletName} }
							4 { Write-Log -Message "Robocopy completed. Some Mismatched files or directories were detected. Examine the output log. Housekeeping might be required." -Severity 2 -Source ${CmdletName} }
							5 { Write-Log -Message "Robocopy completed. Some files were copied. Some files were mismatched. No failure was encountered." -Source ${CmdletName} }
							6 { Write-Log -Message "Robocopy completed. Additional files and mismatched files exist. No files were copied and no failures were encountered meaning that the files already exist in the destination directory." -Severity 2 -Source ${CmdletName} }
							7 { Write-Log -Message "Robocopy completed. Files were copied, a file mismatch was present, and additional files were present." -Severity 2 -Source ${CmdletName} }
							8 { Write-Log -Message "Robocopy completed. Several files didn't copy." -Severity 2 -Source ${CmdletName} }
							16 {
								Write-Log -Message "Serious error. Robocopy did not copy any files. Either a usage error or an error due to insufficient access privileges on the source or destination directories.." -Severity 3 -Source ${CmdletName}
								If (-not $ContinueOnError)
								{
									Throw "Failed to copy file(s) in path [$srcPath] to destination [$Destination]: $($_.Exception.Message)"
								}
							}
							default {
								Write-Log -Message "Failed to copy file(s) in path [$srcPath] to destination [$Destination]. `r`n$(Resolve-Error)" -Severity 3 -Source ${CmdletName}
								If (-not $ContinueOnError)
								{
									Throw "Failed to copy file(s) in path [$srcPath] to destination [$Destination]: $($_.Exception.Message)"
								}
							}
						}
					}
				}
				Catch
				{
					Write-Log -Message "Failed to copy file(s) in path [$srcPath] to destination [$Destination]. `r`n$(Resolve-Error)" -Severity 3 -Source ${CmdletName}
					If (-not $ContinueOnError)
					{
						Throw "Failed to copy file(s) in path [$srcPath] to destination [$Destination]: $($_.Exception.Message)"
					}
				}
			}
			If ($UseRobocopyThis -eq $false)
			{
				Try
				{
					# If destination has no extension, or if it has an extension only and no name (e.g. a .config folder) and the destination folder does not exist
					If ((-not ([IO.Path]::HasExtension($Destination))) -or ([IO.Path]::HasExtension($Destination) -and -not [IO.Path]::GetFileNameWithoutExtension($Destination)) -and (-not (Test-Path -LiteralPath $Destination -PathType 'Container')))
					{
						Write-Log -Message "Destination assumed to be a folder which does not exist, creating destination folder [$Destination]." -Source ${CmdletName}
						$null = New-Item -Path $Destination -Type 'Directory' -Force -ErrorAction 'Stop'
					}
					# If destination appears to be a file name but parent folder does not exist, create it
					$DestinationParent = Split-Path $Destination -Parent
					If ([IO.Path]::HasExtension($Destination) -and [IO.Path]::GetFileNameWithoutExtension($Destination) -and -not (Test-Path -LiteralPath $DestinationParent -PathType 'Container'))
					{
						Write-Log -Message "Destination assumed to be a file whose parent folder does not exist, creating destination folder [$DestinationParent]." -Source ${CmdletName}
						$null = New-Item -Path $DestinationParent -Type 'Directory' -Force -ErrorAction 'Stop'
					}
					If ($Flatten)
					{
						Write-Log -Message "Copying file(s) recursively in path [$srcPath] to destination [$Destination] root folder, flattened." -Source ${CmdletName}
						If ($ContinueFileCopyOnError)
						{
							$null = Get-ChildItem -Path $srcPath -File -Recurse -Force -ErrorAction 'SilentlyContinue' | ForEach-Object {
								Copy-Item -Path ($_.FullName) -Destination $Destination -Force -ErrorAction 'SilentlyContinue' -ErrorVariable 'FileCopyError'
							}
						}
						Else
						{
							$null = Get-ChildItem -Path $srcPath -File -Recurse -Force -ErrorAction 'SilentlyContinue' | ForEach-Object {
								Copy-Item -Path ($_.FullName) -Destination $Destination -Force -ErrorAction 'Stop'
							}
						}
					}
					ElseIf ($Recurse)
					{
						Write-Log -Message "Copying file(s) recursively in path [$srcPath] to destination [$Destination]." -Source ${CmdletName}
						If ($ContinueFileCopyOnError)
						{
							$null = Copy-Item -Path $srcPath -Destination $Destination -Force -Recurse -ErrorAction 'SilentlyContinue' -ErrorVariable 'FileCopyError'
						}
						Else
						{
							$null = Copy-Item -Path $srcPath -Destination $Destination -Force -Recurse -ErrorAction 'Stop'
						}
					}
					Else
					{
						Write-Log -Message "Copying file in path [$srcPath] to destination [$Destination]." -Source ${CmdletName}
						If ($ContinueFileCopyOnError)
						{
							$null = Copy-Item -Path $srcPath -Destination $Destination -Force -ErrorAction 'SilentlyContinue' -ErrorVariable 'FileCopyError'
						}
						Else
						{
							$null = Copy-Item -Path $srcPath -Destination $Destination -Force -ErrorAction 'Stop'
						}
					}
					
					If ($FileCopyError)
					{
						Write-Log -Message "The following warnings were detected while copying file(s) in path [$srcPath] to destination [$Destination]. `r`n$FileCopyError" -Severity 2 -Source ${CmdletName}
					}
					Else
					{
						Write-Log -Message 'File copy completed successfully.' -Source ${CmdletName}
					}
				}
				Catch
				{
					Write-Log -Message "Failed to copy file(s) in path [$srcPath] to destination [$Destination]. `r`n$(Resolve-Error)" -Severity 3 -Source ${CmdletName}
					If (-not $ContinueOnError)
					{
						Throw "Failed to copy file(s) in path [$srcPath] to destination [$Destination]: $($_.Exception.Message)"
					}
				}
			}
		}
	}
	End
	{
		Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -Footer
	}
}
#endregion

#region Function Execute-Process
Function Execute-Process
{
<#
.SYNOPSIS
	Execute a process with optional arguments, working directory, window style.
.DESCRIPTION
	Executes a process, e.g. a file included in the Files directory of the App Deploy Toolkit, or a file on the local machine.
	Provides various options for handling the return codes (see Parameters).
.PARAMETER Path
	Path to the file to be executed. If the file is located directly in the "Files" directory of the App Deploy Toolkit, only the file name needs to be specified.
	Otherwise, the full path of the file must be specified. If the files is in a subdirectory of "Files", use the "$dirFiles" variable as shown in the example.
.PARAMETER Parameters
	Arguments to be passed to the executable
.PARAMETER SecureParameters
	Hides all parameters passed to the executable from the Toolkit log file
.PARAMETER WindowStyle
	Style of the window of the process executed. Options: Normal, Hidden, Maximized, Minimized. Default: Normal.
	Note: Not all processes honor the "Hidden" flag. If it it not working, then check the command line options for the process being executed to see it has a silent option.
.PARAMETER CreateNoWindow
	Specifies whether the process should be started with a new window to contain it. Default is false.
.PARAMETER WorkingDirectory
	The working directory used for executing the process. Defaults to the directory of the file being executed.
.PARAMETER NoWait
	Immediately continue after executing the process.
.PARAMETER PassThru
	Returns ExitCode, STDOut, and STDErr output from the process.
.PARAMETER WaitForMsiExec
	Sometimes an EXE bootstrapper will launch an MSI install. In such cases, this variable will ensure that
	this function waits for the msiexec engine to become available before starting the install.
.PARAMETER MsiExecWaitTime
	Specify the length of time in seconds to wait for the msiexec engine to become available. Default: 600 seconds (10 minutes).
.PARAMETER IgnoreExitCodes
	List the exit codes to ignore.
.PARAMETER ContinueOnError
	Continue if an exit code is returned by the process that is not recognized by the App Deploy Toolkit. Default: $false.
.EXAMPLE
	Execute-Process -Path 'uninstall_flash_player_64bit.exe' -Parameters '/uninstall' -WindowStyle 'Hidden'
	If the file is in the "Files" directory of the App Deploy Toolkit, only the file name needs to be specified.
.EXAMPLE
	Execute-Process -Path "$dirFiles\Bin\setup.exe" -Parameters '/S' -WindowStyle 'Hidden'
.EXAMPLE
	Execute-Process -Path 'setup.exe' -Parameters '/S' -IgnoreExitCodes '1,2'
.EXAMPLE
	Execute-Process -Path 'setup.exe' -Parameters "-s -f2`"$configToolkitLogDir\$installName.log`""
	Launch InstallShield "setup.exe" from the ".\Files" sub-directory and force log files to the logging folder.
.EXAMPLE
	Execute-Process -Path 'setup.exe' -Parameters "/s /v`"ALLUSERS=1 /qn /L* \`"$configToolkitLogDir\$installName.log`"`""
	Launch InstallShield "setup.exe" with embedded MSI and force log files to the logging folder.
.NOTES
.LINK
	http://psappdeploytoolkit.com
#>
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $true)]
		[Alias('FilePath')]
		[ValidateNotNullorEmpty()]
		[string]$Path,
		[Parameter(Mandatory = $false)]
		[Alias('Arguments')]
		[ValidateNotNullorEmpty()]
		[string[]]$Parameters,
		[Parameter(Mandatory = $false)]
		[switch]$SecureParameters = $false,
		[Parameter(Mandatory = $false)]
		[ValidateSet('Normal', 'Hidden', 'Maximized', 'Minimized')]
		[Diagnostics.ProcessWindowStyle]$WindowStyle = 'Normal',
		[Parameter(Mandatory = $false)]
		[ValidateNotNullorEmpty()]
		[switch]$CreateNoWindow = $false,
		[Parameter(Mandatory = $false)]
		[ValidateNotNullorEmpty()]
		[string]$WorkingDirectory,
		[Parameter(Mandatory = $false)]
		[switch]$NoWait = $false,
		[Parameter(Mandatory = $false)]
		[switch]$PassThru = $false,
		[Parameter(Mandatory = $false)]
		[switch]$WaitForMsiExec = $false,
		[Parameter(Mandatory = $false)]
		[ValidateNotNullorEmpty()]
		[int]$MsiExecWaitTime = $configMSIMutexWaitTime,
		[Parameter(Mandatory = $false)]
		[ValidateNotNullorEmpty()]
		[string]$IgnoreExitCodes,
		[Parameter(Mandatory = $false)]
		[ValidateNotNullorEmpty()]
		[boolean]$ContinueOnError = $false
	)
	
	Begin
	{
		## Get the name of this function and write header
		[string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
		Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -CmdletBoundParameters $PSBoundParameters -Header
	}
	Process
	{
		Try
		{
			$private:returnCode = $null
			
			## Validate and find the fully qualified path for the $Path variable.
			If (([IO.Path]::IsPathRooted($Path)) -and ([IO.Path]::HasExtension($Path)))
			{
				Write-Log -Message "[$Path] is a valid fully qualified path, continue." -Source ${CmdletName}
				If (-not (Test-Path -LiteralPath $Path -PathType 'Leaf' -ErrorAction 'Stop'))
				{
					Throw "File [$Path] not found."
				}
			}
			Else
			{
				#  The first directory to search will be the 'Files' subdirectory of the script directory
				[string]$PathFolders = $dirFiles
				#  Add the current location of the console (Windows always searches this location first)
				[string]$PathFolders = $PathFolders + ';' + (Get-Location -PSProvider 'FileSystem').Path
				#  Add the new path locations to the PATH environment variable
				$env:PATH = $PathFolders + ';' + $env:PATH
				
				#  Get the fully qualified path for the file. Get-Command searches PATH environment variable to find this value.
				[string]$FullyQualifiedPath = Get-Command -Name $Path -CommandType 'Application' -TotalCount 1 -Syntax -ErrorAction 'Stop'
				
				#  Revert the PATH environment variable to it's original value
				$env:PATH = $env:PATH -replace [regex]::Escape($PathFolders + ';'), ''
				
				If ($FullyQualifiedPath)
				{
					Write-Log -Message "[$Path] successfully resolved to fully qualified path [$FullyQualifiedPath]." -Source ${CmdletName}
					$Path = $FullyQualifiedPath
				}
				Else
				{
					Throw "[$Path] contains an invalid path or file name."
				}
			}
			
			## Set the Working directory (if not specified)
			If (-not $WorkingDirectory) { $WorkingDirectory = Split-Path -Path $Path -Parent -ErrorAction 'Stop' }
			
			## If MSI install, check to see if the MSI installer service is available or if another MSI install is already underway.
			## Please note that a race condition is possible after this check where another process waiting for the MSI installer
			##  to become available grabs the MSI Installer mutex before we do. Not too concerned about this possible race condition.
			If (($Path -match 'msiexec') -or ($WaitForMsiExec))
			{
				[timespan]$MsiExecWaitTimeSpan = New-TimeSpan -Seconds $MsiExecWaitTime
				[boolean]$MsiExecAvailable = Test-IsMutexAvailable -MutexName 'Global\_MSIExecute' -MutexWaitTimeInMilliseconds $MsiExecWaitTimeSpan.TotalMilliseconds
				Start-Sleep -Seconds 1
				If (-not $MsiExecAvailable)
				{
					#  Default MSI exit code for install already in progress
					[int32]$returnCode = 1618
					Throw 'Please complete in progress MSI installation before proceeding with this install.'
				}
			}
			
			Try
			{
				## Disable Zone checking to prevent warnings when running executables
				$env:SEE_MASK_NOZONECHECKS = 1
				
				## Using this variable allows capture of exceptions from .NET methods. Private scope only changes value for current function.
				$private:previousErrorActionPreference = $ErrorActionPreference
				$ErrorActionPreference = 'Stop'
				
				## Define process
				$processStartInfo = New-Object -TypeName 'System.Diagnostics.ProcessStartInfo' -ErrorAction 'Stop'
				$processStartInfo.FileName = $Path
				$processStartInfo.WorkingDirectory = $WorkingDirectory
				$processStartInfo.UseShellExecute = $false
				$processStartInfo.ErrorDialog = $false
				$processStartInfo.RedirectStandardOutput = $true
				$processStartInfo.RedirectStandardError = $true
				$processStartInfo.CreateNoWindow = $CreateNoWindow
				If ($Parameters) { $processStartInfo.Arguments = $Parameters }
				If ($windowStyle) { $processStartInfo.WindowStyle = $WindowStyle }
				$process = New-Object -TypeName 'System.Diagnostics.Process' -ErrorAction 'Stop'
				$process.StartInfo = $processStartInfo
				
				## Add event handler to capture process's standard output redirection
				[scriptblock]$processEventHandler = { If (-not [string]::IsNullOrEmpty($EventArgs.Data)) { $Event.MessageData.AppendLine($EventArgs.Data) } }
				$stdOutBuilder = New-Object -TypeName 'System.Text.StringBuilder' -ArgumentList ''
				$stdOutEvent = Register-ObjectEvent -InputObject $process -Action $processEventHandler -EventName 'OutputDataReceived' -MessageData $stdOutBuilder -ErrorAction 'Stop'
				
				## Start Process
				Write-Log -Message "Working Directory is [$WorkingDirectory]." -Source ${CmdletName}
				If ($Parameters)
				{
					If ($Parameters -match '-Command \&')
					{
						Write-Log -Message "Executing [$Path [PowerShell ScriptBlock]]..." -Source ${CmdletName}
					}
					Else
					{
						If ($SecureParameters)
						{
							Write-Log -Message "Executing [$Path (Parameters Hidden)]..." -Source ${CmdletName}
						}
						Else
						{
							Write-Log -Message "Executing [$Path $Parameters]..." -Source ${CmdletName}
						}
					}
				}
				Else
				{
					Write-Log -Message "Executing [$Path]..." -Source ${CmdletName}
				}
				[boolean]$processStarted = $process.Start()
				
				If ($NoWait)
				{
					Write-Log -Message 'NoWait parameter specified. Continuing without waiting for exit code...' -Source ${CmdletName}
				}
				Else
				{
					$process.BeginOutputReadLine()
					$stdErr = $($process.StandardError.ReadToEnd()).ToString() -replace $null, ''
					
					## Instructs the Process component to wait indefinitely for the associated process to exit.
					$process.WaitForExit()
					
					## HasExited indicates that the associated process has terminated, either normally or abnormally. Wait until HasExited returns $true.
					While (-not ($process.HasExited)) { $process.Refresh(); Start-Sleep -Seconds 1 }
					
					## Get the exit code for the process
					Try
					{
						[int32]$returnCode = $process.ExitCode
					}
					Catch [System.Management.Automation.PSInvalidCastException] {
						#  Catch exit codes that are out of int32 range
						[int32]$returnCode = 60013
					}
					
					## Unregister standard output event to retrieve process output
					If ($stdOutEvent) { Unregister-Event -SourceIdentifier $stdOutEvent.Name -ErrorAction 'Stop'; $stdOutEvent = $null }
					$stdOut = $stdOutBuilder.ToString() -replace $null, ''
					
					If ($stdErr.Length -gt 0)
					{
						Write-Log -Message "Standard error output from the process: $stdErr" -Severity 3 -Source ${CmdletName}
					}
				}
			}
			Finally
			{
				## Make sure the standard output event is unregistered
				If ($stdOutEvent) { Unregister-Event -SourceIdentifier $stdOutEvent.Name -ErrorAction 'Stop' }
				
				## Free resources associated with the process, this does not cause process to exit
				If ($process) { $process.Close() }
				
				## Re-enable Zone checking
				Remove-Item -LiteralPath 'env:SEE_MASK_NOZONECHECKS' -ErrorAction 'SilentlyContinue'
				
				If ($private:previousErrorActionPreference) { $ErrorActionPreference = $private:previousErrorActionPreference }
			}
			
			If (-not $NoWait)
			{
				## Check to see whether we should ignore exit codes
				$ignoreExitCodeMatch = $false
				If ($ignoreExitCodes)
				{
					#  Split the processes on a comma
					[int32[]]$ignoreExitCodesArray = $ignoreExitCodes -split ','
					ForEach ($ignoreCode in $ignoreExitCodesArray)
					{
						If ($returnCode -eq $ignoreCode) { $ignoreExitCodeMatch = $true }
					}
				}
				#  Or always ignore exit codes
				If ($ContinueOnError) { $ignoreExitCodeMatch = $true }
				
				## If the passthru switch is specified, return the exit code and any output from process
				If ($PassThru)
				{
					Write-Log -Message "Execution completed with exit code [$returnCode]." -Source ${CmdletName}
					[psobject]$ExecutionResults = New-Object -TypeName 'PSObject' -Property @{ ExitCode = $returnCode; StdOut = $stdOut; StdErr = $stdErr }
					Write-Output -InputObject $ExecutionResults
				}
				ElseIf ($ignoreExitCodeMatch)
				{
					Write-Log -Message "Execution complete and the exit code [$returncode] is being ignored." -Source ${CmdletName}
				}
				ElseIf (($returnCode -eq 3010) -or ($returnCode -eq 1641))
				{
					Write-Log -Message "Execution completed successfully with exit code [$returnCode]. A reboot is required." -Severity 2 -Source ${CmdletName}
					Set-Variable -Name 'msiRebootDetected' -Value $true -Scope 'Script'
				}
				ElseIf (($returnCode -eq 1605) -and ($Path -match 'msiexec'))
				{
					Write-Log -Message "Execution failed with exit code [$returnCode] because the product is not currently installed." -Severity 3 -Source ${CmdletName}
				}
				ElseIf (($returnCode -eq -2145124329) -and ($Path -match 'wusa'))
				{
					Write-Log -Message "Execution failed with exit code [$returnCode] because the Windows Update is not applicable to this system." -Severity 3 -Source ${CmdletName}
				}
				ElseIf (($returnCode -eq 17025) -and ($Path -match 'fullfile'))
				{
					Write-Log -Message "Execution failed with exit code [$returnCode] because the Office Update is not applicable to this system." -Severity 3 -Source ${CmdletName}
				}
				ElseIf ($returnCode -eq 0)
				{
					Write-Log -Message "Execution completed successfully with exit code [$returnCode]." -Source ${CmdletName}
				}
				Else
				{
					[string]$MsiExitCodeMessage = ''
					If ($Path -match 'msiexec')
					{
						[string]$MsiExitCodeMessage = Get-MsiExitCodeMessage -MsiExitCode $returnCode
					}
					
					If ($MsiExitCodeMessage)
					{
						Write-Log -Message "Execution failed with exit code [$returnCode]: $MsiExitCodeMessage" -Severity 3 -Source ${CmdletName}
					}
					Else
					{
						Write-Log -Message "Execution failed with exit code [$returnCode]." -Severity 3 -Source ${CmdletName}
					}
					Exit-Script -ExitCode $returnCode
				}
			}
		}
		Catch
		{
			If ([string]::IsNullOrEmpty([string]$returnCode))
			{
				[int32]$returnCode = 60002
				Write-Log -Message "Function failed, setting exit code to [$returnCode]. `n$(Resolve-Error)" -Severity 3 -Source ${CmdletName}
			}
			Else
			{
				Write-Log -Message "Execution completed with exit code [$returnCode]. Function failed. `n$(Resolve-Error)" -Severity 3 -Source ${CmdletName}
			}
			If ($PassThru)
			{
				[psobject]$ExecutionResults = New-Object -TypeName 'PSObject' -Property @{ ExitCode = $returnCode; StdOut = If ($stdOut) { $stdOut } Else { '' }; StdErr = If ($stdErr) { $stdErr } Else { '' } }
				Write-Output -InputObject $ExecutionResults
			}
			Else
			{
				Exit-Script -ExitCode $returnCode
			}
		}
	}
	End
	{
		Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -Footer
	}
}
#endregion

#region Function Get-MsiTableProperty
Function Get-MsiTableProperty
{
<#
.SYNOPSIS
	Get all of the properties from a Windows Installer database table or the Summary Information stream and return as a custom object.
.DESCRIPTION
	Use the Windows Installer object to read all of the properties from a Windows Installer database table or the Summary Information stream.
.DEPENDENCIES
	Get-ObjectProperty
	Invoke-ObjectMethod
.PARAMETER Path
	The fully qualified path to an database file. Supports .msi and .msp files.
.PARAMETER TransformPath
	The fully qualified path to a list of MST file(s) which should be applied to the MSI file.
.PARAMETER Table
	The name of the the MSI table from which all of the properties must be retrieved. Default is: 'Property'.
.PARAMETER TablePropertyNameColumnNum
	Specify the table column number which contains the name of the properties. Default is: 1 for MSIs and 2 for MSPs.
.PARAMETER TablePropertyValueColumnNum
	Specify the table column number which contains the value of the properties. Default is: 2 for MSIs and 3 for MSPs.
.PARAMETER GetSummaryInformation
	Retrieves the Summary Information for the Windows Installer database.
	Summary Information property descriptions: https://msdn.microsoft.com/en-us/library/aa372049(v=vs.85).aspx
.PARAMETER ContinueOnError
	Continue if an error is encountered. Default is: $true.
.EXAMPLE
	Get-MsiTableProperty -Path 'C:\Package\AppDeploy.msi' -TransformPath 'C:\Package\AppDeploy.mst'
	Retrieve all of the properties from the default 'Property' table.
.EXAMPLE
	Get-MsiTableProperty -Path 'C:\Package\AppDeploy.msi' -TransformPath 'C:\Package\AppDeploy.mst' -Table 'Property' | Select-Object -ExpandProperty ProductCode
	Retrieve all of the properties from the 'Property' table and then pipe to Select-Object to select the ProductCode property.
.EXAMPLE
	Get-MsiTableProperty -Path 'C:\Package\AppDeploy.msi' -GetSummaryInformation
	Retrieves the Summary Information for the Windows Installer database.
.NOTES
	This is an internal script function and should typically not be called directly.
.LINK
	http://psappdeploytoolkit.com
#>
	[CmdletBinding(DefaultParameterSetName = 'TableInfo')]
	Param (
		[Parameter(Mandatory = $true)]
		[ValidateScript({ Test-Path -LiteralPath $_ -PathType 'Leaf' })]
		[string]$Path,
		[Parameter(Mandatory = $false)]
		[ValidateScript({ Test-Path -LiteralPath $_ -PathType 'Leaf' })]
		[string[]]$TransformPath,
		[Parameter(Mandatory = $false, ParameterSetName = 'TableInfo')]
		[ValidateNotNullOrEmpty()]
		[string]$Table = $(If ([IO.Path]::GetExtension($Path) -eq '.msi') { 'Property' }
			Else { 'MsiPatchMetadata' }),
		[Parameter(Mandatory = $false, ParameterSetName = 'TableInfo')]
		[ValidateNotNullorEmpty()]
		[int32]$TablePropertyNameColumnNum = $(If ([IO.Path]::GetExtension($Path) -eq '.msi') { 1 }
			Else { 2 }),
		[Parameter(Mandatory = $false, ParameterSetName = 'TableInfo')]
		[ValidateNotNullorEmpty()]
		[int32]$TablePropertyValueColumnNum = $(If ([IO.Path]::GetExtension($Path) -eq '.msi') { 2 }
			Else { 3 }),
		[Parameter(Mandatory = $true, ParameterSetName = 'SummaryInfo')]
		[ValidateNotNullorEmpty()]
		[switch]$GetSummaryInformation = $false,
		[Parameter(Mandatory = $false)]
		[ValidateNotNullorEmpty()]
		[boolean]$ContinueOnError = $true
	)
	
	Begin
	{
		## Get the name of this function and write header
		[string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
		
		Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -CmdletBoundParameters $PSBoundParameters -Header
	}
	Process
	{
		Try
		{
			If ($PSCmdlet.ParameterSetName -eq 'TableInfo')
			{
				Write-Log -Message "Read data from Windows Installer database file [$Path] in table [$Table]." -Source ${CmdletName}
			}
			Else
			{
				Write-Log -Message "Read the Summary Information from the Windows Installer database file [$Path]." -Source ${CmdletName}
			}
			
			## Create a Windows Installer object
			[__comobject]$Installer = New-Object -ComObject 'WindowsInstaller.Installer' -ErrorAction 'Stop'
			## Determine if the database file is a patch (.msp) or not
			If ([IO.Path]::GetExtension($Path) -eq '.msp') { [boolean]$IsMspFile = $true }
			## Define properties for how the MSI database is opened
			[int32]$msiOpenDatabaseModeReadOnly = 0
			[int32]$msiSuppressApplyTransformErrors = 63
			[int32]$msiOpenDatabaseMode = $msiOpenDatabaseModeReadOnly
			[int32]$msiOpenDatabaseModePatchFile = 32
			If ($IsMspFile) { [int32]$msiOpenDatabaseMode = $msiOpenDatabaseModePatchFile }
			## Open database in read only mode
			[__comobject]$Database = Invoke-ObjectMethod -InputObject $Installer -MethodName 'OpenDatabase' -ArgumentList @($Path, $msiOpenDatabaseMode)
			## Apply a list of transform(s) to the database
			If (($TransformPath) -and (-not $IsMspFile))
			{
				ForEach ($Transform in $TransformPath)
				{
					$null = Invoke-ObjectMethod -InputObject $Database -MethodName 'ApplyTransform' -ArgumentList @($Transform, $msiSuppressApplyTransformErrors)
				}
			}
			
			## Get either the requested windows database table information or summary information
			If ($PSCmdlet.ParameterSetName -eq 'TableInfo')
			{
				## Open the requested table view from the database
				[__comobject]$View = Invoke-ObjectMethod -InputObject $Database -MethodName 'OpenView' -ArgumentList @("SELECT * FROM $Table")
				$null = Invoke-ObjectMethod -InputObject $View -MethodName 'Execute'
				
				## Create an empty object to store properties in
				[psobject]$TableProperties = New-Object -TypeName 'PSObject'
				
				## Retrieve the first row from the requested table. If the first row was successfully retrieved, then save data and loop through the entire table.
				#  https://msdn.microsoft.com/en-us/library/windows/desktop/aa371136(v=vs.85).aspx
				[__comobject]$Record = Invoke-ObjectMethod -InputObject $View -MethodName 'Fetch'
				While ($Record)
				{
					#  Read string data from record and add property/value pair to custom object
					$TableProperties | Add-Member -MemberType 'NoteProperty' -Name (Get-ObjectProperty -InputObject $Record -PropertyName 'StringData' -ArgumentList @($TablePropertyNameColumnNum)) -Value (Get-ObjectProperty -InputObject $Record -PropertyName 'StringData' -ArgumentList @($TablePropertyValueColumnNum)) -Force
					#  Retrieve the next row in the table
					[__comobject]$Record = Invoke-ObjectMethod -InputObject $View -MethodName 'Fetch'
				}
				Write-Output -InputObject $TableProperties
			}
			Else
			{
				## Get the SummaryInformation from the windows installer database
				[__comobject]$SummaryInformation = Get-ObjectProperty -InputObject $Database -PropertyName 'SummaryInformation'
				[hashtable]$SummaryInfoProperty = @{ }
				## Summary property descriptions: https://msdn.microsoft.com/en-us/library/aa372049(v=vs.85).aspx
				$SummaryInfoProperty.Add('CodePage', (Get-ObjectProperty -InputObject $SummaryInformation -PropertyName 'Property' -ArgumentList @(1)))
				$SummaryInfoProperty.Add('Title', (Get-ObjectProperty -InputObject $SummaryInformation -PropertyName 'Property' -ArgumentList @(2)))
				$SummaryInfoProperty.Add('Subject', (Get-ObjectProperty -InputObject $SummaryInformation -PropertyName 'Property' -ArgumentList @(3)))
				$SummaryInfoProperty.Add('Author', (Get-ObjectProperty -InputObject $SummaryInformation -PropertyName 'Property' -ArgumentList @(4)))
				$SummaryInfoProperty.Add('Keywords', (Get-ObjectProperty -InputObject $SummaryInformation -PropertyName 'Property' -ArgumentList @(5)))
				$SummaryInfoProperty.Add('Comments', (Get-ObjectProperty -InputObject $SummaryInformation -PropertyName 'Property' -ArgumentList @(6)))
				$SummaryInfoProperty.Add('Template', (Get-ObjectProperty -InputObject $SummaryInformation -PropertyName 'Property' -ArgumentList @(7)))
				$SummaryInfoProperty.Add('LastSavedBy', (Get-ObjectProperty -InputObject $SummaryInformation -PropertyName 'Property' -ArgumentList @(8)))
				$SummaryInfoProperty.Add('RevisionNumber', (Get-ObjectProperty -InputObject $SummaryInformation -PropertyName 'Property' -ArgumentList @(9)))
				$SummaryInfoProperty.Add('LastPrinted', (Get-ObjectProperty -InputObject $SummaryInformation -PropertyName 'Property' -ArgumentList @(11)))
				$SummaryInfoProperty.Add('CreateTimeDate', (Get-ObjectProperty -InputObject $SummaryInformation -PropertyName 'Property' -ArgumentList @(12)))
				$SummaryInfoProperty.Add('LastSaveTimeDate', (Get-ObjectProperty -InputObject $SummaryInformation -PropertyName 'Property' -ArgumentList @(13)))
				$SummaryInfoProperty.Add('PageCount', (Get-ObjectProperty -InputObject $SummaryInformation -PropertyName 'Property' -ArgumentList @(14)))
				$SummaryInfoProperty.Add('WordCount', (Get-ObjectProperty -InputObject $SummaryInformation -PropertyName 'Property' -ArgumentList @(15)))
				$SummaryInfoProperty.Add('CharacterCount', (Get-ObjectProperty -InputObject $SummaryInformation -PropertyName 'Property' -ArgumentList @(16)))
				$SummaryInfoProperty.Add('CreatingApplication', (Get-ObjectProperty -InputObject $SummaryInformation -PropertyName 'Property' -ArgumentList @(18)))
				$SummaryInfoProperty.Add('Security', (Get-ObjectProperty -InputObject $SummaryInformation -PropertyName 'Property' -ArgumentList @(19)))
				[psobject]$SummaryInfoProperties = New-Object -TypeName 'PSObject' -Property $SummaryInfoProperty
				Write-Output -InputObject $SummaryInfoProperties
			}
		}
		Catch
		{
			Write-Log -Message "Failed to get the MSI table [$Table]. `n$(Resolve-Error)" -Severity 3 -Source ${CmdletName}
			If (-not $ContinueOnError)
			{
				Throw "Failed to get the MSI table [$Table]: $($_.Exception.Message)"
			}
		}
		Finally
		{
			Try
			{
				If ($View)
				{
					$null = Invoke-ObjectMethod -InputObject $View -MethodName 'Close' -ArgumentList @()
					Try { $null = [Runtime.Interopservices.Marshal]::ReleaseComObject($View) }
					Catch { }
				}
				ElseIf ($SummaryInformation)
				{
					Try { $null = [Runtime.Interopservices.Marshal]::ReleaseComObject($SummaryInformation) }
					Catch { }
				}
			}
			Catch { }
			Try { $null = [Runtime.Interopservices.Marshal]::ReleaseComObject($DataBase) }
			Catch { }
			Try { $null = [Runtime.Interopservices.Marshal]::ReleaseComObject($Installer) }
			Catch { }
		}
	}
	End
	{
		Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -Footer
	}
}
#endregion

#region Function Invoke-ObjectMethod
Function Invoke-ObjectMethod
{
<#
.SYNOPSIS
	Invoke method on any object.
.DESCRIPTION
	Invoke method on any object with or without using named parameters.
.PARAMETER InputObject
	Specifies an object which has methods that can be invoked.
.PARAMETER MethodName
	Specifies the name of a method to invoke.
.PARAMETER ArgumentList
	Argument to pass to the method being executed. Allows execution of method without specifying named parameters.
.PARAMETER Parameter
	Argument to pass to the method being executed. Allows execution of method by using named parameters.
.EXAMPLE
	$ShellApp = New-Object -ComObject 'Shell.Application'
	$null = Invoke-ObjectMethod -InputObject $ShellApp -MethodName 'MinimizeAll'
	Minimizes all windows.
.EXAMPLE
	$ShellApp = New-Object -ComObject 'Shell.Application'
	$null = Invoke-ObjectMethod -InputObject $ShellApp -MethodName 'Explore' -Parameter @{'vDir'='C:\Windows'}
	Opens the C:\Windows folder in a Windows Explorer window.
.NOTES
	This is an internal script function and should typically not be called directly.
.LINK
	http://psappdeploytoolkit.com
#>
	[CmdletBinding(DefaultParameterSetName = 'Positional')]
	Param (
		[Parameter(Mandatory = $true, Position = 0)]
		[ValidateNotNull()]
		[object]$InputObject,
		[Parameter(Mandatory = $true, Position = 1)]
		[ValidateNotNullorEmpty()]
		[string]$MethodName,
		[Parameter(Mandatory = $false, Position = 2, ParameterSetName = 'Positional')]
		[object[]]$ArgumentList,
		[Parameter(Mandatory = $true, Position = 2, ParameterSetName = 'Named')]
		[ValidateNotNull()]
		[hashtable]$Parameter
	)
	
	Begin { }
	Process
	{
		If ($PSCmdlet.ParameterSetName -eq 'Named')
		{
			## Invoke method by using parameter names
			Write-Output -InputObject $InputObject.GetType().InvokeMember($MethodName, [Reflection.BindingFlags]::InvokeMethod, $null, $InputObject, ([object[]]($Parameter.Values)), $null, $null, ([string[]]($Parameter.Keys)))
		}
		Else
		{
			## Invoke method without using parameter names
			Write-Output -InputObject $InputObject.GetType().InvokeMember($MethodName, [Reflection.BindingFlags]::InvokeMethod, $null, $InputObject, $ArgumentList, $null, $null, $null)
		}
	}
	End { }
}
#endregion

#region Function Get-ObjectProperty
Function Get-ObjectProperty
{
<#
.SYNOPSIS
	Get a property from any object.
.DESCRIPTION
	Get a property from any object.
.DEPENDENCIES
	None
.PARAMETER InputObject
	Specifies an object which has properties that can be retrieved.
.PARAMETER PropertyName
	Specifies the name of a property to retrieve.
.PARAMETER ArgumentList
	Argument to pass to the property being retrieved.
.EXAMPLE
	Get-ObjectProperty -InputObject $Record -PropertyName 'StringData' -ArgumentList @(1)
.NOTES
	This is an internal script function and should typically not be called directly.
.LINK
	http://psappdeploytoolkit.com
#>
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $true, Position = 0)]
		[ValidateNotNull()]
		[object]$InputObject,
		[Parameter(Mandatory = $true, Position = 1)]
		[ValidateNotNullorEmpty()]
		[string]$PropertyName,
		[Parameter(Mandatory = $false, Position = 2)]
		[object[]]$ArgumentList
	)
	
	Begin { }
	Process
	{
		## Retrieve property
		Write-Output -InputObject $InputObject.GetType().InvokeMember($PropertyName, [Reflection.BindingFlags]::GetProperty, $null, $InputObject, $ArgumentList, $null, $null, $null)
	}
	End { }
}
#endregion

#region Function Get-MsiExitCodeMessage
Function Get-MsiExitCodeMessage
{
<#
.SYNOPSIS
	Get message for MSI error code
.DESCRIPTION
	Get message for MSI error code by reading it from msimsg.dll
.PARAMETER MsiErrorCode
	MSI error code
.EXAMPLE
	Get-MsiExitCodeMessage -MsiErrorCode 1618
.NOTES
	This is an internal script function and should typically not be called directly.
.LINK
	http://msdn.microsoft.com/en-us/library/aa368542(v=vs.85).aspx
	http://psappdeploytoolkit.com
#>
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $true)]
		[ValidateNotNullorEmpty()]
		[int32]$MsiExitCode
	)
	
	Begin
	{
		## Get the name of this function and write header
		[string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
		Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -CmdletBoundParameters $PSBoundParameters -Header
	}
	Process
	{
		Try
		{
			Write-Log -Message "Get message for exit code [$MsiExitCode]." -Source ${CmdletName}
			Switch ($MsiExitCode)
			{
				(0) { $MsiExitCodeMsg = 'ERROR_SUCCESS'; $ErrorDescription = 'The action completed successfully.' }
				(13) { $MsiExitCodeMsg = 'ERROR_INVALID_DATA'; $ErrorDescription = 'The data is invalid.' }
				(87) { $MsiExitCodeMsg = 'ERROR_INVALID_PARAMETER'; $ErrorDescription = 'One of the parameters was invalid.' }
				(120) { $MsiExitCodeMsg = 'ERROR_CALL_NOT_IMPLEMENTED'; $ErrorDescription = 'This value is returned when a custom action attempts to call a function that cannot be called from custom actions. The function returns the value ERROR_CALL_NOT_IMPLEMENTED. Available beginning with Windows Installer version 3.0.' }
				(1259) { $MsiExitCodeMsg = 'ERROR_APPHELP_BLOCK'; $ErrorDescription = 'If Windows Installer determines a product may be incompatible with the current operating system, it displays a dialog box informing the user and asking whether to try to install anyway. This error code is returned if the user chooses not to try the installation.' }
				(1601) { $MsiExitCodeMsg = 'ERROR_INSTALL_SERVICE_FAILURE'; $ErrorDescription = 'The Windows Installer service could not be accessed. Contact your support personnel to verify that the Windows Installer service is properly registered.' }
				(1602) { $MsiExitCodeMsg = 'ERROR_INSTALL_USEREXIT'; $ErrorDescription = 'The user cancels installation.' }
				(1603) { $MsiExitCodeMsg = 'ERROR_INSTALL_FAILURE'; $ErrorDescription = 'A fatal error occurred during installation.' }
				(1604) { $MsiExitCodeMsg = 'ERROR_INSTALL_SUSPEND'; $ErrorDescription = 'Installation suspended, incomplete.' }
				(1605) { $MsiExitCodeMsg = 'ERROR_UNKNOWN_PRODUCT'; $ErrorDescription = 'This action is only valid for products that are currently installed.' }
				(1606) { $MsiExitCodeMsg = 'ERROR_UNKNOWN_FEATURE'; $ErrorDescription = 'The feature identifier is not registered.' }
				(1607) { $MsiExitCodeMsg = 'ERROR_UNKNOWN_COMPONENT'; $ErrorDescription = 'The component identifier is not registered.' }
				(1608) { $MsiExitCodeMsg = 'ERROR_UNKNOWN_PROPERTY'; $ErrorDescription = 'This is an unknown property.' }
				(1609) { $MsiExitCodeMsg = 'ERROR_INVALID_HANDLE_STATE'; $ErrorDescription = 'The handle is in an invalid state.' }
				(1610) { $MsiExitCodeMsg = 'ERROR_BAD_CONFIGURATION'; $ErrorDescription = 'The configuration data for this product is corrupt. Contact your support personnel.' }
				(1611) { $MsiExitCodeMsg = 'ERROR_INDEX_ABSENT'; $ErrorDescription = 'The component qualifier not present.' }
				(1612) { $MsiExitCodeMsg = 'ERROR_INSTALL_SOURCE_ABSENT'; $ErrorDescription = 'The installation source for this product is not available. Verify that the source exists and that you can access it.' }
				(1613) { $MsiExitCodeMsg = 'ERROR_INSTALL_PACKAGE_VERSION'; $ErrorDescription = 'This installation package cannot be installed by the Windows Installer service. You must install a Windows service pack that contains a newer version of the Windows Installer service.' }
				(1614) { $MsiExitCodeMsg = 'ERROR_PRODUCT_UNINSTALLED'; $ErrorDescription = 'The product is uninstalled.' }
				(1615) { $MsiExitCodeMsg = 'ERROR_BAD_QUERY_SYNTAX'; $ErrorDescription = 'The SQL query syntax is invalid or unsupported.' }
				(1616) { $MsiExitCodeMsg = 'ERROR_INVALID_FIELD'; $ErrorDescription = 'The record field does not exist.' }
				(1618) { $MsiExitCodeMsg = 'ERROR_INSTALL_ALREADY_RUNNING'; $ErrorDescription = 'Another installation is already in progress. Complete that installation before proceeding with this install. For information about the mutex, see _MSIExecute Mutex.' }
				(1619) { $MsiExitCodeMsg = 'ERROR_INSTALL_PACKAGE_OPEN_FAILED'; $ErrorDescription = 'This installation package could not be opened. Verify that the package exists and is accessible, or contact the application vendor to verify that this is a valid Windows Installer package.' }
				(1620) { $MsiExitCodeMsg = 'ERROR_INSTALL_PACKAGE_INVALID'; $ErrorDescription = 'This installation package could not be opened. Contact the application vendor to verify that this is a valid Windows Installer package.' }
				(1621) { $MsiExitCodeMsg = 'ERROR_INSTALL_UI_FAILURE'; $ErrorDescription = 'There was an error starting the Windows Installer service user interface. Contact your support personnel.' }
				(1622) { $MsiExitCodeMsg = 'ERROR_INSTALL_LOG_FAILURE'; $ErrorDescription = 'There was an error opening installation log file. Verify that the specified log file location exists and is writable.' }
				(1623) { $MsiExitCodeMsg = 'ERROR_INSTALL_LANGUAGE_UNSUPPORTED'; $ErrorDescription = 'This language of this installation package is not supported by your system.' }
				(1624) { $MsiExitCodeMsg = 'ERROR_INSTALL_TRANSFORM_FAILURE'; $ErrorDescription = 'There was an error applying transforms. Verify that the specified transform paths are valid.' }
				(1625) { $MsiExitCodeMsg = 'ERROR_INSTALL_PACKAGE_REJECTED'; $ErrorDescription = 'This installation is forbidden by system policy. Contact your system administrator.' }
				(1626) { $MsiExitCodeMsg = 'ERROR_FUNCTION_NOT_CALLED'; $ErrorDescription = 'The function could not be executed.' }
				(1627) { $MsiExitCodeMsg = 'ERROR_FUNCTION_FAILED'; $ErrorDescription = 'The function failed during execution.' }
				(1628) { $MsiExitCodeMsg = 'ERROR_INVALID_TABLE'; $ErrorDescription = 'An invalid or unknown table was specified.' }
				(1629) { $MsiExitCodeMsg = 'ERROR_DATATYPE_MISMATCH'; $ErrorDescription = 'The data supplied is the wrong type.' }
				(1630) { $MsiExitCodeMsg = 'ERROR_UNSUPPORTED_TYPE'; $ErrorDescription = 'Data of this type is not supported.' }
				(1631) { $MsiExitCodeMsg = 'ERROR_CREATE_FAILED'; $ErrorDescription = 'The Windows Installer service failed to start. Contact your support personnel.' }
				(1632) { $MsiExitCodeMsg = 'ERROR_INSTALL_TEMP_UNWRITABLE'; $ErrorDescription = 'The Temp folder is either full or inaccessible. Verify that the Temp folder exists and that you can write to it.' }
				(1633) { $MsiExitCodeMsg = 'ERROR_INSTALL_PLATFORM_UNSUPPORTED'; $ErrorDescription = 'This installation package is not supported on this platform. Contact your application vendor.' }
				(1634) { $MsiExitCodeMsg = 'ERROR_INSTALL_NOTUSED'; $ErrorDescription = 'Component is not used on this machine.' }
				(1635) { $MsiExitCodeMsg = 'ERROR_PATCH_PACKAGE_OPEN_FAILED'; $ErrorDescription = 'This patch package could not be opened. Verify that the patch package exists and is accessible, or contact the application vendor to verify that this is a valid Windows Installer patch package.' }
				(1636) { $MsiExitCodeMsg = 'ERROR_PATCH_PACKAGE_INVALID'; $ErrorDescription = 'This patch package could not be opened. Contact the application vendor to verify that this is a valid Windows Installer patch package.' }
				(1637) { $MsiExitCodeMsg = 'ERROR_PATCH_PACKAGE_UNSUPPORTED'; $ErrorDescription = 'This patch package cannot be processed by the Windows Installer service. You must install a Windows service pack that contains a newer version of the Windows Installer service.' }
				(1638) { $MsiExitCodeMsg = 'ERROR_PRODUCT_VERSION'; $ErrorDescription = 'Another version of this product is already installed. Installation of this version cannot continue.' }
				(1639) { $MsiExitCodeMsg = 'ERROR_INVALID_COMMAND_LINE'; $ErrorDescription = 'Invalid command line argument. Consult the Windows Installer SDK for detailed command-line help.' }
				(1640) { $MsiExitCodeMsg = 'ERROR_INSTALL_REMOTE_DISALLOWED'; $ErrorDescription = 'The current user is not permitted to perform installations from a client session of a server running the Terminal Server role service.' }
				(1641) { $MsiExitCodeMsg = 'ERROR_SUCCESS_REBOOT_INITIATED'; $ErrorDescription = 'The installer has initiated a restart. This message is indicative of a success.' }
				(1642) { $MsiExitCodeMsg = 'ERROR_PATCH_TARGET_NOT_FOUND'; $ErrorDescription = 'The installer cannot install the upgrade patch because the program being upgraded may be missing or the upgrade patch updates a different version of the program. Verify that the program to be upgraded exists on your computer and that you have the correct upgrade patch.' }
				(1643) { $MsiExitCodeMsg = 'ERROR_PATCH_PACKAGE_REJECTED'; $ErrorDescription = 'The patch package is not permitted by system policy.' }
				(1644) { $MsiExitCodeMsg = 'ERROR_INSTALL_TRANSFORM_REJECTED'; $ErrorDescription = 'One or more customizations are not permitted by system policy.' }
				(1645) { $MsiExitCodeMsg = 'ERROR_INSTALL_REMOTE_PROHIBITED'; $ErrorDescription = 'Windows Installer does not permit installation from a Remote Desktop Connection.' }
				(1646) { $MsiExitCodeMsg = 'ERROR_PATCH_REMOVAL_UNSUPPORTED'; $ErrorDescription = 'The patch package is not a removable patch package. Available beginning with Windows Installer version 3.0.' }
				(1647) { $MsiExitCodeMsg = 'ERROR_UNKNOWN_PATCH'; $ErrorDescription = 'The patch is not applied to this product. Available beginning with Windows Installer version 3.0.' }
				(1648) { $MsiExitCodeMsg = 'ERROR_PATCH_NO_SEQUENCE'; $ErrorDescription = 'No valid sequence could be found for the set of patches. Available beginning with Windows Installer version 3.0.' }
				(1649) { $MsiExitCodeMsg = 'ERROR_PATCH_REMOVAL_DISALLOWED'; $ErrorDescription = 'Patch removal was disallowed by policy. Available beginning with Windows Installer version 3.0.' }
				(1650) { $MsiExitCodeMsg = 'ERROR_INVALID_PATCH_XML'; $ErrorDescription = 'The XML patch data is invalid. Available beginning with Windows Installer version 3.0.' }
				(1651) { $MsiExitCodeMsg = 'ERROR_PATCH_MANAGED_ADVERTISED_PRODUCT'; $ErrorDescription = 'Administrative user failed to apply patch for a per-user managed or a per-machine application that is in advertise state. Available beginning with Windows Installer version 3.0.' }
				(1652) { $MsiExitCodeMsg = 'ERROR_INSTALL_SERVICE_SAFEBOOT'; $ErrorDescription = 'Windows Installer is not accessible when the computer is in Safe Mode.' }
				(1653) { $MsiExitCodeMsg = 'ERROR_ROLLBACK_DISABLED'; $ErrorDescription = 'Could not perform a multiple-package transaction because rollback has been disabled. ' }
				(1654) { $MsiExitCodeMsg = 'ERROR_INSTALL_REJECTED'; $ErrorDescription = 'The app that you are trying to run is not supported on this version of Windows. A Windows Installer package, patch, or transform that has not been signed by Microsoft cannot be installed on an ARM computer.' }
				(3010) { $MsiExitCodeMsg = 'ERROR_SUCCESS_REBOOT_REQUIRED'; $ErrorDescription = 'A reboot is needed to complete the install' }
				default{ $MsiExitCodeMsg = 'ERROR_UNKNOWN_CODE'; $ErrorDescription = '' }
			}
			Write-Log -Message "$MsiExitCodeMsg : $ErrorDescription" -Source ${CmdletName}
			Write-Output -InputObject $MsiExitCodeMsg
		}
		Catch
		{
			Write-Log -Message "Failed to get message for exit code [$MsiExitCode]. `n$(Resolve-Error)" -Severity 3 -Source ${CmdletName}
		}
	}
	End
	{
		Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -Footer
	}
}
#endregion

#region Function Get-UserProfiles
Function Get-UserProfiles
{
    <#
.SYNOPSIS

Get the User Profile Path, User Account Sid, and the User Account Name for all users that log onto the machine and also the Default User (which does not log on).

.DESCRIPTION

Get the User Profile Path, User Account Sid, and the User Account Name for all users that log onto the machine and also the Default User (which does  not log on).

Please note that the NTAccount property may be empty for some user profiles but the SID and ProfilePath properties will always be populated.

.PARAMETER ExcludeNTAccount

Specify NT account names in Domain\Username format to exclude from the list of user profiles.

.PARAMETER ExcludeSystemProfiles

Exclude system profiles: SYSTEM, LOCAL SERVICE, NETWORK SERVICE. Default is: $true.

.PARAMETER ExcludeServiceProfiles

Exclude service profiles where NTAccount begins with NT SERVICE. Default is: $true.

.PARAMETER ExcludeDefaultUser

Exclude the Default User. Default is: $false.

.INPUTS

None

You cannot pipe objects to this function.

.OUTPUTS

PSObject. Returns a PSObject with the following properties: NTAccount, SID, ProfilePath

.EXAMPLE

Get-UserProfiles

Returns the following properties for each user profile on the system: NTAccount, SID, ProfilePath

.EXAMPLE

Get-UserProfiles -ExcludeNTAccount 'CONTOSO\Robot','CONTOSO\ntadmin'

.EXAMPLE

[String[]]$ProfilePaths = Get-UserProfiles | Select-Object -ExpandProperty 'ProfilePath'

Returns the user profile path for each user on the system. This information can then be used to make modifications under the user profile on the filesystem.

.NOTES

.LINK

https://psappdeploytoolkit.com
#>
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $false)]
		[ValidateNotNullOrEmpty()]
		[String[]]$ExcludeNTAccount,
		[Parameter(Mandatory = $false)]
		[ValidateNotNullOrEmpty()]
		[Boolean]$ExcludeSystemProfiles = $true,
		[Parameter(Mandatory = $false)]
		[ValidateNotNullOrEmpty()]
		[Boolean]$ExcludeServiceProfiles = $true,
		[Parameter(Mandatory = $false)]
		[ValidateNotNullOrEmpty()]
		[Switch]$ExcludeDefaultUser = $false
	)
	
	Begin
	{
		## Get the name of this function and write header
		[String]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
		Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -CmdletBoundParameters $PSBoundParameters -Header
	}
	Process
	{
		Try
		{
			Write-Log -Message 'Getting the User Profile Path, User Account SID, and the User Account Name for all users that log onto the machine.' -Source ${CmdletName}
			
			## Get the User Profile Path, User Account Sid, and the User Account Name for all users that log onto the machine
			[String]$UserProfileListRegKey = 'Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList'
			[PSObject[]]$UserProfiles = Get-ChildItem -LiteralPath $UserProfileListRegKey -ErrorAction 'Stop' |
			ForEach-Object {
				Get-ItemProperty -LiteralPath $_.PSPath -ErrorAction 'Stop' | Where-Object { ($_.ProfileImagePath) } |
				Select-Object @{ Label = 'NTAccount'; Expression = { $(ConvertTo-NTAccountOrSID -SID $_.PSChildName).Value } }, @{ Label = 'SID'; Expression = { $_.PSChildName } }, @{ Label = 'ProfilePath'; Expression = { $_.ProfileImagePath } }
			} |
			Where-Object { $_.NTAccount } # This removes the "defaultuser0" account, which is a Windows 10 bug
			If ($ExcludeSystemProfiles)
			{
				[String[]]$SystemProfiles = 'S-1-5-18', 'S-1-5-19', 'S-1-5-20'
				[PSObject[]]$UserProfiles = $UserProfiles | Where-Object { $SystemProfiles -notcontains $_.SID }
			}
			If ($ExcludeServiceProfiles)
			{
				[PSObject[]]$UserProfiles = $UserProfiles | Where-Object { $_.NTAccount -notlike 'NT SERVICE\*' }
			}
			If ($ExcludeNTAccount)
			{
				[PSObject[]]$UserProfiles = $UserProfiles | Where-Object { $ExcludeNTAccount -notcontains $_.NTAccount }
			}
			
			## Find the path to the Default User profile
			If (-not $ExcludeDefaultUser)
			{
				[String]$UserProfilesDirectory = Get-ItemProperty -LiteralPath $UserProfileListRegKey -Name 'ProfilesDirectory' -ErrorAction 'Stop' | Select-Object -ExpandProperty 'ProfilesDirectory'
				
				#  On Windows Vista or higher
				If (([Version]$envOSVersion).Major -gt 5)
				{
					# Path to Default User Profile directory on Windows Vista or higher: By default, C:\Users\Default
					[string]$DefaultUserProfileDirectory = Get-ItemProperty -LiteralPath $UserProfileListRegKey -Name 'Default' -ErrorAction 'Stop' | Select-Object -ExpandProperty 'Default'
				}
				#  On Windows XP or lower
				Else
				{
					#  Default User Profile Name: By default, 'Default User'
					[string]$DefaultUserProfileName = Get-ItemProperty -LiteralPath $UserProfileListRegKey -Name 'DefaultUserProfile' -ErrorAction 'Stop' | Select-Object -ExpandProperty 'DefaultUserProfile'
					
					#  Path to Default User Profile directory: By default, C:\Documents and Settings\Default User
					[String]$DefaultUserProfileDirectory = Join-Path -Path $UserProfilesDirectory -ChildPath $DefaultUserProfileName
				}
				
				## Create a custom object for the Default User profile.
				#  Since the Default User is not an actual User account, it does not have a username or a SID.
				#  We will make up a SID and add it to the custom object so that we have a location to load the default registry hive into later on.
				[PSObject]$DefaultUserProfile = New-Object -TypeName 'PSObject' -Property @{
					NTAccount   = 'Default User'
					SID		    = 'S-1-5-21-Default-User'
					ProfilePath = $DefaultUserProfileDirectory
				}
				
				## Add the Default User custom object to the User Profile list.
				$UserProfiles += $DefaultUserProfile
			}
			
			Write-Output -InputObject ($UserProfiles)
		}
		Catch
		{
			Write-Log -Message "Failed to create a custom object representing all user profiles on the machine. `r`n$(Resolve-Error)" -Severity 3 -Source ${CmdletName}
		}
	}
	End
	{
		Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -Footer
	}
}
#endregion

#region Function ConvertTo-NTAccountOrSID
Function ConvertTo-NTAccountOrSID{
<#
.SYNOPSIS
	Convert between NT Account names and their security identifiers (SIDs).
.DESCRIPTION
	Specify either the NT Account name or the SID and get the other. Can also convert well known sid types.
.PARAMETER AccountName
	The Windows NT Account name specified in <domain>\<username> format.
	Use fully qualified account names (e.g., <domain>\<username>) instead of isolated names (e.g, <username>) because they are unambiguous and provide better performance.
.PARAMETER SID
	The Windows NT Account SID.
.PARAMETER WellKnownSIDName
	Specify the Well Known SID name translate to the actual SID (e.g., LocalServiceSid).
	To get all well known SIDs available on system: [enum]::GetNames([Security.Principal.WellKnownSidType])
.PARAMETER WellKnownToNTAccount
	Convert the Well Known SID to an NTAccount name
.EXAMPLE
	ConvertTo-NTAccountOrSID -AccountName 'CONTOSO\User1'
	Converts a Windows NT Account name to the corresponding SID
.EXAMPLE
	ConvertTo-NTAccountOrSID -SID 'S-1-5-21-1220945662-2111687655-725345543-14012660'
	Converts a Windows NT Account SID to the corresponding NT Account Name
.EXAMPLE
	ConvertTo-NTAccountOrSID -WellKnownSIDName 'NetworkServiceSid'
	Converts a Well Known SID name to a SID
.NOTES
	This is an internal script function and should typically not be called directly.
	The conversion can return an empty result if the user account does not exist anymore or if translation fails.
	http://blogs.technet.com/b/askds/archive/2011/07/28/troubleshooting-sid-translation-failures-from-the-obvious-to-the-not-so-obvious.aspx
.LINK
	http://psappdeploytoolkit.com
	List of Well Known SIDs: http://msdn.microsoft.com/en-us/library/system.security.principal.wellknownsidtype(v=vs.110).aspx
#>
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $true, ParameterSetName = 'NTAccountToSID', ValueFromPipelineByPropertyName = $true)]
		[ValidateNotNullOrEmpty()]
		[string]$AccountName,
		[Parameter(Mandatory = $true, ParameterSetName = 'SIDToNTAccount', ValueFromPipelineByPropertyName = $true)]
		[ValidateNotNullOrEmpty()]
		[string]$SID,
		[Parameter(Mandatory = $true, ParameterSetName = 'WellKnownName', ValueFromPipelineByPropertyName = $true)]
		[ValidateNotNullOrEmpty()]
		[string]$WellKnownSIDName,
		[Parameter(Mandatory = $false, ParameterSetName = 'WellKnownName')]
		[ValidateNotNullOrEmpty()]
		[switch]$WellKnownToNTAccount
	)
	
	Begin
	{
		## Get the name of this function and write header
		[string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
		Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -CmdletBoundParameters $PSBoundParameters -Header
	}
	Process
	{
		Try
		{
			Switch ($PSCmdlet.ParameterSetName)
			{
				'SIDToNTAccount' {
					[string]$msg = "the SID [$SID] to an NT Account name"
					Write-Log -Message "Convert $msg." -Source ${CmdletName}
					
					$NTAccountSID = New-Object -TypeName 'System.Security.Principal.SecurityIdentifier' -ArgumentList $SID
					$NTAccount = $NTAccountSID.Translate([Security.Principal.NTAccount])
					Write-Output -InputObject $NTAccount
				}
				'NTAccountToSID' {
					[string]$msg = "the NT Account [$AccountName] to a SID"
					Write-Log -Message "Convert $msg." -Source ${CmdletName}
					
					$NTAccount = New-Object -TypeName 'System.Security.Principal.NTAccount' -ArgumentList $AccountName
					$NTAccountSID = $NTAccount.Translate([Security.Principal.SecurityIdentifier])
					Write-Output -InputObject $NTAccountSID
				}
				'WellKnownName' {
					If ($WellKnownToNTAccount)
					{
						[string]$ConversionType = 'NTAccount'
					}
					Else
					{
						[string]$ConversionType = 'SID'
					}
					[string]$msg = "the Well Known SID Name [$WellKnownSIDName] to a $ConversionType"
					Write-Log -Message "Convert $msg." -Source ${CmdletName}
					
					#  Get the SID for the root domain
					Try
					{
						$MachineRootDomain = (Get-WmiObject -Class 'Win32_ComputerSystem' -ErrorAction 'Stop').Domain.ToLower()
						$ADDomainObj = New-Object -TypeName 'System.DirectoryServices.DirectoryEntry' -ArgumentList "LDAP://$MachineRootDomain"
						$DomainSidInBinary = $ADDomainObj.ObjectSid
						$DomainSid = New-Object -TypeName 'System.Security.Principal.SecurityIdentifier' -ArgumentList ($DomainSidInBinary[0], 0)
					}
					Catch
					{
						Write-Log -Message 'Unable to get Domain SID from Active Directory. Setting Domain SID to $null.' -Severity 2 -Source ${CmdletName}
						$DomainSid = $null
					}
					
					#  Get the SID for the well known SID name
					$WellKnownSidType = [Security.Principal.WellKnownSidType]::$WellKnownSIDName
					$NTAccountSID = New-Object -TypeName 'System.Security.Principal.SecurityIdentifier' -ArgumentList ($WellKnownSidType, $DomainSid)
					
					If ($WellKnownToNTAccount)
					{
						$NTAccount = $NTAccountSID.Translate([Security.Principal.NTAccount])
						Write-Output -InputObject $NTAccount
					}
					Else
					{
						Write-Output -InputObject $NTAccountSID
					}
				}
			}
		}
		Catch
		{
			Write-Log -Message "Failed to convert $msg. It may not be a valid account anymore or there is some other problem. `n$(Resolve-Error)" -Severity 3 -Source ${CmdletName}
		}
	}
	End
	{
		Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -Footer
	}
}
#endregion

#region Function Get-PendingReboot
Function Get-PendingReboot
{
<#
.SYNOPSIS
	Get the pending reboot status on a local computer.
.DESCRIPTION
	Check WMI and the registry to determine if the system has a pending reboot operation from any of the following:
	a) Component Based Servicing (Vista, Windows 2008)
	b) Windows Update / Auto Update (XP, Windows 2003 / 2008)
	c) SCCM 2012 Clients (DetermineIfRebootPending WMI method)
	d) App-V Pending Tasks (global based Appv 5.0 SP2)
	e) Pending File Rename Operations (XP, Windows 2003 / 2008)
.DEPENDENCIES
	Test-RegistryValue
	Resolve-Error
.EXAMPLE
	Get-PendingReboot

	Returns custom object with following properties:
	ComputerName, LastBootUpTime, IsSystemRebootPending, IsCBServicingRebootPending, IsWindowsUpdateRebootPending, IsSCCMClientRebootPending, IsFileRenameRebootPending, PendingFileRenameOperations, ErrorMsg

	*Notes: ErrorMsg only contains something if an error occurred
.EXAMPLE
	(Get-PendingReboot).IsSystemRebootPending
	Returns boolean value determining whether or not there is a pending reboot operation.
.NOTES
.LINK
	http://psappdeploytoolkit.com
#>
	[CmdletBinding()]
	Param (
		[Switch]$Silent
	)
	
	Begin
	{
		## Get the name of this function and write header
		[string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
		Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -CmdletBoundParameters $PSBoundParameters -Header
		
		## Initialize variables
		[string]$private:ComputerName = ([Net.Dns]::GetHostEntry('')).HostName
		$PendRebootErrorMsg = $null
	}
	Process
	{
		if (-not $Silent) { Write-Log -Message "Get the pending reboot status on the local computer [$ComputerName]." -Source ${CmdletName} }
		
		## Get the date/time that the system last booted up
		Try
		{
			[nullable[datetime]]$LastBootUpTime = (Get-Date -ErrorAction 'Stop') - ([timespan]::FromMilliseconds([math]::Abs([Environment]::TickCount)))
		}
		Catch
		{
			[nullable[datetime]]$LastBootUpTime = $null
			[string[]]$PendRebootErrorMsg += "Failed to get LastBootUpTime: $($_.Exception.Message)"
			if (-not $Silent) { Write-Log -Message "Failed to get LastBootUpTime. `n$(Resolve-Error)" -Severity 3 -Source ${CmdletName} }
		}
		
		## Determine if a Windows Vista/Server 2008 and above machine has a pending reboot from a Component Based Servicing (CBS) operation
		Try
		{
			If (([version]$envOSVersion).Major -ge 5)
			{
				If (Test-Path -LiteralPath 'HKLM:SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending' -ErrorAction 'Stop')
				{
					[nullable[boolean]]$IsCBServicingRebootPending = $true
				}
				Else
				{
					[nullable[boolean]]$IsCBServicingRebootPending = $false
				}
			}
		}
		Catch
		{
			[nullable[boolean]]$IsCBServicingRebootPending = $null
			[string[]]$PendRebootErrorMsg += "Failed to get IsCBServicingRebootPending: $($_.Exception.Message)"
			if (-not $Silent) { Write-Log -Message "Failed to get IsCBServicingRebootPending. `n$(Resolve-Error)" -Severity 3 -Source ${CmdletName} }
		}
		
		## Determine if there is a pending reboot from a Windows Update
		Try
		{
			If (Test-Path -LiteralPath 'HKLM:SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired' -ErrorAction 'Stop')
			{
				[nullable[boolean]]$IsWindowsUpdateRebootPending = $true
			}
			Else
			{
				[nullable[boolean]]$IsWindowsUpdateRebootPending = $false
			}
		}
		Catch
		{
			[nullable[boolean]]$IsWindowsUpdateRebootPending = $null
			[string[]]$PendRebootErrorMsg += "Failed to get IsWindowsUpdateRebootPending: $($_.Exception.Message)"
			if (-not $Silent) { Write-Log -Message "Failed to get IsWindowsUpdateRebootPending. `n$(Resolve-Error)" -Severity 3 -Source ${CmdletName} }
		}
		
		## Determine if there is a pending reboot from a pending file rename operation
		[boolean]$IsFileRenameRebootPending = $false
		$PendingFileRenameOperations = $null
		$testRegValueSplat = @{
			'Key' = 'HKLM:SYSTEM\CurrentControlSet\Control\Session Manager'
			'Value' = 'PendingFileRenameOperations'
		}
		if ($Silent) { $testRegValueSplat.Add('Silent',$true) }
		If (Test-RegistryValue @testRegValueSplat)
		{
			#  If PendingFileRenameOperations value exists, set $IsFileRenameRebootPending variable to $true
			[boolean]$IsFileRenameRebootPending = $true
			#  Get the value of PendingFileRenameOperations
			Try
			{
				[string[]]$PendingFileRenameOperations = Get-ItemProperty -LiteralPath 'HKLM:SYSTEM\CurrentControlSet\Control\Session Manager' -ErrorAction 'Stop' | Select-Object -ExpandProperty 'PendingFileRenameOperations' -ErrorAction 'Stop'
			}
			Catch
			{
				[string[]]$PendRebootErrorMsg += "Failed to get PendingFileRenameOperations: $($_.Exception.Message)"
				if (-not $Silent) { Write-Log -Message "Failed to get PendingFileRenameOperations. `n$(Resolve-Error)" -Severity 3 -Source ${CmdletName} }
			}
		}
		
		## Determine SCCM 2012 Client reboot pending status
		Try
		{
			[boolean]$IsSccmClientNamespaceExists = $false
			[psobject]$SCCMClientRebootStatus = Invoke-WmiMethod -ComputerName $ComputerName -NameSpace 'ROOT\CCM\ClientSDK' -Class 'CCM_ClientUtilities' -Name 'DetermineIfRebootPending' -ErrorAction 'Stop'
			[boolean]$IsSccmClientNamespaceExists = $true
			If ($SCCMClientRebootStatus.ReturnValue -ne 0)
			{
				Throw "'DetermineIfRebootPending' method of 'ROOT\CCM\ClientSDK\CCM_ClientUtilities' class returned error code [$($SCCMClientRebootStatus.ReturnValue)]"
			}
			Else
			{
				if (-not $Silent) { Write-Log -Message 'Successfully queried SCCM client for reboot status.' -Source ${CmdletName} }
				[nullable[boolean]]$IsSCCMClientRebootPending = $false
				If ($SCCMClientRebootStatus.IsHardRebootPending -or $SCCMClientRebootStatus.RebootPending)
				{
					[nullable[boolean]]$IsSCCMClientRebootPending = $true
					if (-not $Silent) { Write-Log -Message 'Pending SCCM reboot detected.' -Source ${CmdletName} }
				}
				Else
				{
					if (-not $Silent) { Write-Log -Message 'Pending SCCM reboot not detected.' -Source ${CmdletName} }
				}
			}
		}
		Catch [System.Management.ManagementException] {
			[nullable[boolean]]$IsSCCMClientRebootPending = $null
			[boolean]$IsSccmClientNamespaceExists = $false
			if (-not $Silent) { Write-Log -Message "Failed to get IsSCCMClientRebootPending. Failed to detect the SCCM client WMI class." -Severity 3 -Source ${CmdletName} }
		}
		Catch
		{
			[nullable[boolean]]$IsSCCMClientRebootPending = $null
			[string[]]$PendRebootErrorMsg += "Failed to get IsSCCMClientRebootPending: $($_.Exception.Message)"
			if (-not $Silent) { Write-Log -Message "Failed to get IsSCCMClientRebootPending. `n$(Resolve-Error)" -Severity 3 -Source ${CmdletName} }
		}
		
		## Determine if there is a pending reboot from an App-V global Pending Task. (User profile based tasks will complete on logoff/logon)
		Try
		{
			If (Test-Path -LiteralPath 'HKLM:SOFTWARE\Software\Microsoft\AppV\Client\PendingTasks' -ErrorAction 'Stop')
			{
				
				[nullable[boolean]]$IsAppVRebootPending = $true
			}
			Else
			{
				[nullable[boolean]]$IsAppVRebootPending = $false
			}
		}
		Catch
		{
			[nullable[boolean]]$IsAppVRebootPending = $null
			[string[]]$PendRebootErrorMsg += "Failed to get IsAppVRebootPending: $($_.Exception.Message)"
			if (-not $Silent) { Write-Log -Message "Failed to get IsAppVRebootPending. `n$(Resolve-Error)" -Severity 3 -Source ${CmdletName} }
		}
		
		## Determine if there is a pending reboot for the system
		[boolean]$IsSystemRebootPending = $false
		If ($IsCBServicingRebootPending -or $IsWindowsUpdateRebootPending -or $IsSCCMClientRebootPending -or $IsFileRenameRebootPending)
		{
			[boolean]$IsSystemRebootPending = $true
		}
		
		## Create a custom object containing pending reboot information for the system
		[psobject]$PendingRebootInfo = New-Object -TypeName 'PSObject' -Property @{
			ComputerName				 = $ComputerName
			LastBootUpTime			     = $LastBootUpTime
			IsSystemRebootPending	     = $IsSystemRebootPending
			IsCBServicingRebootPending   = $IsCBServicingRebootPending
			IsWindowsUpdateRebootPending = $IsWindowsUpdateRebootPending
			IsSCCMClientRebootPending    = $IsSCCMClientRebootPending
			IsAppVRebootPending		     = $IsAppVRebootPending
			IsFileRenameRebootPending    = $IsFileRenameRebootPending
			PendingFileRenameOperations  = $PendingFileRenameOperations
			ErrorMsg					 = $PendRebootErrorMsg
		}
		if (-not $Silent) { Write-Log -Message "Pending reboot status on the local computer [$ComputerName]: `n$($PendingRebootInfo | Format-List | Out-String)" -Source ${CmdletName} }
	}
	End
	{
		Write-Output -InputObject ($PendingRebootInfo | Select-Object -Property 'ComputerName', 'LastBootUpTime', 'IsSystemRebootPending', 'IsCBServicingRebootPending', 'IsWindowsUpdateRebootPending', 'IsSCCMClientRebootPending', 'IsAppVRebootPending', 'IsFileRenameRebootPending', 'PendingFileRenameOperations', 'ErrorMsg')
		
		Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -Footer
	}
}
#endregion

#region Function Get-RegistryKey
Function Get-RegistryKey
{
<#
.SYNOPSIS
	Retrieves value names and value data for a specified registry key or optionally, a specific value.
.DESCRIPTION
	Retrieves value names and value data for a specified registry key or optionally, a specific value.
	If the registry key does not exist or contain any values, the function will return $null by default. To test for existence of a registry key path, use built-in Test-Path cmdlet.
.DEPENDENCIES
	Resolve-Error
	Convert-RegistryPath
.PARAMETER Key
	Path of the registry key.
.PARAMETER Value
	Value to retrieve (optional).
.PARAMETER SID
	The security identifier (SID) for a user. Specifying this parameter will convert a HKEY_CURRENT_USER registry key to the HKEY_USERS\$SID format.
	Specify this parameter from the Invoke-HKCURegistrySettingsForAllUsers function to read/edit HKCU registry settings for all users on the system.
.PARAMETER ReturnEmptyKeyIfExists
	Return the registry key if it exists but it has no property/value pairs underneath it. Default is: $false.
.PARAMETER DoNotExpandEnvironmentNames
	Return unexpanded REG_EXPAND_SZ values. Default is: $false.
.PARAMETER ContinueOnError
	Continue if an error is encountered. Default is: $true.
.EXAMPLE
	Get-RegistryKey -Key 'HKLM:SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\{1AD147D0-BE0E-3D6C-AC11-64F6DC4163F1}'
.EXAMPLE
	Get-RegistryKey -Key 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\iexplore.exe'
.EXAMPLE
	Get-RegistryKey -Key 'HKLM:Software\Wow6432Node\Microsoft\Microsoft SQL Server Compact Edition\v3.5' -Value 'Version'
.EXAMPLE
	Get-RegistryKey -Key 'HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Session Manager\Environment' -Value 'Path' -DoNotExpandEnvironmentNames
	Returns %ProgramFiles%\Java instead of C:\Program Files\Java
.EXAMPLE
	Get-RegistryKey -Key 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Example' -Value '(Default)'
.NOTES
.LINK
	http://psappdeploytoolkit.com
#>
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $true)]
		[ValidateNotNullorEmpty()]
		[string]$Key,
		[Parameter(Mandatory = $false)]
		[ValidateNotNullOrEmpty()]
		[string]$Value,
		[Parameter(Mandatory = $false)]
		[ValidateNotNullorEmpty()]
		[string]$SID,
		[Parameter(Mandatory = $false)]
		[ValidateNotNullorEmpty()]
		[switch]$ReturnEmptyKeyIfExists = $false,
		[Parameter(Mandatory = $false)]
		[ValidateNotNullorEmpty()]
		[switch]$DoNotExpandEnvironmentNames = $false,
		[Parameter(Mandatory = $false)]
		[ValidateNotNullOrEmpty()]
		[boolean]$ContinueOnError = $true
	)
	
	Begin
	{
		## Get the name of this function and write header
		[string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
		Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -CmdletBoundParameters $PSBoundParameters -Header
	}
	Process
	{
		Try
		{
			## If the SID variable is specified, then convert all HKEY_CURRENT_USER key's to HKEY_USERS\$SID
			If ($PSBoundParameters.ContainsKey('SID'))
			{
				[string]$key = Convert-RegistryPath -Key $key -SID $SID
			}
			Else
			{
				[string]$key = Convert-RegistryPath -Key $key
			}
			
			## Check if the registry key exists
			If (-not (Test-Path -LiteralPath $key -ErrorAction 'Stop'))
			{
				Write-Log -Message "Registry key [$key] does not exist. Return `$null." -Severity 2 -Source ${CmdletName}
				$regKeyValue = $null
			}
			Else
			{
				If ($PSBoundParameters.ContainsKey('Value'))
				{
					Write-Log -Message "Get registry key [$key] value [$value]." -Source ${CmdletName}
				}
				Else
				{
					Write-Log -Message "Get registry key [$key] and all property values." -Source ${CmdletName}
				}
				
				## Get all property values for registry key
				$regKeyValue = Get-ItemProperty -LiteralPath $key -ErrorAction 'Stop'
				[int32]$regKeyValuePropertyCount = $regKeyValue | Measure-Object | Select-Object -ExpandProperty 'Count'
				
				## Select requested property
				If ($PSBoundParameters.ContainsKey('Value'))
				{
					#  Check if registry value exists
					[boolean]$IsRegistryValueExists = $false
					If ($regKeyValuePropertyCount -gt 0)
					{
						Try
						{
							[string[]]$PathProperties = Get-Item -LiteralPath $Key -ErrorAction 'Stop' | Select-Object -ExpandProperty 'Property' -ErrorAction 'Stop'
							If ($PathProperties -contains $Value) { $IsRegistryValueExists = $true }
						}
						Catch { }
					}
					
					#  Get the Value (do not make a strongly typed variable because it depends entirely on what kind of value is being read)
					If ($IsRegistryValueExists)
					{
						If ($DoNotExpandEnvironmentNames)
						{
							#Only useful on 'ExpandString' values
							If ($Value -like '(Default)')
							{
								$regKeyValue = $(Get-Item -LiteralPath $key -ErrorAction 'Stop').GetValue($null, $null, [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
							}
							Else
							{
								$regKeyValue = $(Get-Item -LiteralPath $key -ErrorAction 'Stop').GetValue($Value, $null, [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
							}
						}
						ElseIf ($Value -like '(Default)')
						{
							$regKeyValue = $(Get-Item -LiteralPath $key -ErrorAction 'Stop').GetValue($null)
						}
						Else
						{
							$regKeyValue = $regKeyValue | Select-Object -ExpandProperty $Value -ErrorAction 'SilentlyContinue'
						}
					}
					Else
					{
						Write-Log -Message "Registry key value [$Key] [$Value] does not exist. Return `$null." -Source ${CmdletName}
						$regKeyValue = $null
					}
				}
				## Select all properties or return empty key object
				Else
				{
					If ($regKeyValuePropertyCount -eq 0)
					{
						If ($ReturnEmptyKeyIfExists)
						{
							Write-Log -Message "No property values found for registry key. Return empty registry key object [$key]." -Source ${CmdletName}
							$regKeyValue = Get-Item -LiteralPath $key -Force -ErrorAction 'Stop'
						}
						Else
						{
							Write-Log -Message "No property values found for registry key. Return `$null." -Source ${CmdletName}
							$regKeyValue = $null
						}
					}
				}
			}
			Write-Output -InputObject ($regKeyValue)
		}
		Catch
		{
			If (-not $Value)
			{
				Write-Log -Message "Failed to read registry key [$key]. `n$(Resolve-Error)" -Severity 3 -Source ${CmdletName}
				If (-not $ContinueOnError)
				{
					Throw "Failed to read registry key [$key]: $($_.Exception.Message)"
				}
			}
			Else
			{
				Write-Log -Message "Failed to read registry key [$key] value [$value]. `n$(Resolve-Error)" -Severity 3 -Source ${CmdletName}
				If (-not $ContinueOnError)
				{
					Throw "Failed to read registry key [$key] value [$value]: $($_.Exception.Message)"
				}
			}
		}
	}
	End
	{
		Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -Footer
	}
}
#endregion

#region Function Convert-RegistryPath
Function Convert-RegistryPath
{
<#
.SYNOPSIS
	Converts the specified registry key path to a format that is compatible with built-in PowerShell cmdlets.
.DESCRIPTION
	Converts the specified registry key path to a format that is compatible with built-in PowerShell cmdlets.
	Converts registry key hives to their full paths. Example: HKLM is converted to "Registry::HKEY_LOCAL_MACHINE".
.DEPENDENCIES
.PARAMETER Key
	Path to the registry key to convert (can be a registry hive or fully qualified path)
.PARAMETER SID
	The security identifier (SID) for a user. Specifying this parameter will convert a HKEY_CURRENT_USER registry key to the HKEY_USERS\$SID format.
	Specify this parameter from the Invoke-HKCURegistrySettingsForAllUsers function to read/edit HKCU registry settings for all users on the system.
.EXAMPLE
	Convert-RegistryPath -Key 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\{1AD147D0-BE0E-3D6C-AC11-64F6DC4163F1}'
.EXAMPLE
	Convert-RegistryPath -Key 'HKLM:SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\{1AD147D0-BE0E-3D6C-AC11-64F6DC4163F1}'
.NOTES
.LINK
	http://psappdeploytoolkit.com
#>
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $true)]
		[ValidateNotNullorEmpty()]
		[string]$Key,
		[Parameter(Mandatory = $false)]
		[ValidateNotNullorEmpty()]
		[string]$SID,
		[Switch]$Silent
	)
	
	Begin
	{
		## Get the name of this function and write header
		[string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
		Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -CmdletBoundParameters $PSBoundParameters -Header
	}
	Process
	{
		## Convert the registry key hive to the full path, only match if at the beginning of the line
		If ($Key -match '^HKLM:\\|^HKCU:\\|^HKCR:\\|^HKU:\\|^HKCC:\\|^HKPD:\\')
		{
			#  Converts registry paths that start with, e.g.: HKLM:\
			$key = $key -replace '^HKLM:\\', 'HKEY_LOCAL_MACHINE\'
			$key = $key -replace '^HKCR:\\', 'HKEY_CLASSES_ROOT\'
			$key = $key -replace '^HKCU:\\', 'HKEY_CURRENT_USER\'
			$key = $key -replace '^HKU:\\', 'HKEY_USERS\'
			$key = $key -replace '^HKCC:\\', 'HKEY_CURRENT_CONFIG\'
			$key = $key -replace '^HKPD:\\', 'HKEY_PERFORMANCE_DATA\'
		}
		ElseIf ($Key -match '^HKLM:|^HKCU:|^HKCR:|^HKU:|^HKCC:|^HKPD:')
		{
			#  Converts registry paths that start with, e.g.: HKLM:
			$key = $key -replace '^HKLM:', 'HKEY_LOCAL_MACHINE\'
			$key = $key -replace '^HKCR:', 'HKEY_CLASSES_ROOT\'
			$key = $key -replace '^HKCU:', 'HKEY_CURRENT_USER\'
			$key = $key -replace '^HKU:', 'HKEY_USERS\'
			$key = $key -replace '^HKCC:', 'HKEY_CURRENT_CONFIG\'
			$key = $key -replace '^HKPD:', 'HKEY_PERFORMANCE_DATA\'
		}
		ElseIf ($Key -match '^HKLM\\|^HKCU\\|^HKCR\\|^HKU\\|^HKCC\\|^HKPD\\')
		{
			#  Converts registry paths that start with, e.g.: HKLM\
			$key = $key -replace '^HKLM\\', 'HKEY_LOCAL_MACHINE\'
			$key = $key -replace '^HKCR\\', 'HKEY_CLASSES_ROOT\'
			$key = $key -replace '^HKCU\\', 'HKEY_CURRENT_USER\'
			$key = $key -replace '^HKU\\', 'HKEY_USERS\'
			$key = $key -replace '^HKCC\\', 'HKEY_CURRENT_CONFIG\'
			$key = $key -replace '^HKPD\\', 'HKEY_PERFORMANCE_DATA\'
		}
		
		If ($PSBoundParameters.ContainsKey('SID'))
		{
			## If the SID variable is specified, then convert all HKEY_CURRENT_USER key's to HKEY_USERS\$SID
			If ($key -match '^HKEY_CURRENT_USER\\') { $key = $key -replace '^HKEY_CURRENT_USER\\', "HKEY_USERS\$SID\" }
		}
		
		## Append the PowerShell drive to the registry key path
		If ($key -notmatch '^Registry::') { [string]$key = "Registry::$key" }
		
		If ($Key -match '^Registry::HKEY_LOCAL_MACHINE|^Registry::HKEY_CLASSES_ROOT|^Registry::HKEY_CURRENT_USER|^Registry::HKEY_USERS|^Registry::HKEY_CURRENT_CONFIG|^Registry::HKEY_PERFORMANCE_DATA')
		{
			## Check for expected key string format
			if (-not $Silent) { Write-Log -Message "Return fully qualified registry key path [$key]." -Source ${CmdletName} }
			Write-Output -InputObject $key
		}
		Else
		{
			#  If key string is not properly formatted, throw an error
			Throw "Unable to detect target registry hive in string [$key]."
		}
	}
	End
	{
		Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -Footer
	}
}
#endregion

#region Function Remove-MSIApplications
Function Remove-MSIApplications
{
<#
.SYNOPSIS
	Removes all MSI applications matching the specified application name.
.DESCRIPTION
	Removes all MSI applications matching the specified application name.
	Enumerates the registry for installed applications matching the specified application name and uninstalls that application using the product code, provided the uninstall string matches "msiexec".
.PARAMETER Name
	The name of the application to uninstall. Performs a contains match on the application display name by default.
.PARAMETER Exact
	Specifies that the named application must be matched using the exact name.
.PARAMETER WildCard
	Specifies that the named application must be matched using a wildcard search.
.PARAMETER Parameters
	Overrides the default parameters specified in the XML configuration file. Uninstall default is: "REBOOT=ReallySuppress /QN".
.PARAMETER AddParameters
	Adds to the default parameters specified in the XML configuration file. Uninstall default is: "REBOOT=ReallySuppress /QN".
.PARAMETER FilterApplication
	Two-dimensional array that contains one or more (property, value, match-type) sets that should be used to filter the list of results returned by Get-InstalledApplication to only those that should be uninstalled.
	Properties that can be filtered upon: ProductCode, DisplayName, DisplayVersion, UninstallString, InstallSource, InstallLocation, InstallDate, Publisher, Is64BitApplication
.PARAMETER ExcludeFromUninstall
	Two-dimensional array that contains one or more (property, value, match-type) sets that should be excluded from uninstall if found.
	Properties that can be excluded: ProductCode, DisplayName, DisplayVersion, UninstallString, InstallSource, InstallLocation, InstallDate, Publisher, Is64BitApplication
.PARAMETER IncludeUpdatesAndHotfixes
	Include matches against updates and hotfixes in results.
.PARAMETER LoggingOptions
	Overrides the default logging options specified in the XML configuration file. Default options are: "/L*v".
.PARAMETER LogName
	Overrides the default log file name. The default log file name is generated from the MSI file name. If LogName does not end in .log, it will be automatically appended.
	For uninstallations, by default the product code is resolved to the DisplayName and version of the application.
.PARAMETER PassThru
	Returns ExitCode, STDOut, and STDErr output from the process.
.PARAMETER ContinueOnError
	Continue if an exit code is returned by msiexec that is not recognized by the App Deploy Toolkit. Default is: $true.
.EXAMPLE
	Remove-MSIApplications -Name 'Adobe Flash'
	Removes all versions of software that match the name "Adobe Flash"
.EXAMPLE
	Remove-MSIApplications -Name 'Adobe'
	Removes all versions of software that match the name "Adobe"
.EXAMPLE
	Remove-MSIApplications -Name 'Java 8 Update' -FilterApplication ('Is64BitApplication', $false, 'Exact'),('Publisher', 'Oracle Corporation', 'Exact')
	Removes all versions of software that match the name "Java 8 Update" where the software is 32-bits and the publisher is "Oracle Corporation".
.EXAMPLE
	Remove-MSIApplications -Name 'Java 8 Update' -FilterApplication (,('Publisher', 'Oracle Corporation', 'Exact')) -ExcludeFromUninstall (,('DisplayName', 'Java 8 Update 45', 'Contains'))
	Removes all versions of software that match the name "Java 8 Update" and also have "Oracle Corporation" as the Publisher; however, it does not uninstall "Java 8 Update 45" of the software.
	NOTE: if only specifying a single row in the two-dimensional arrays, the array must have the extra parentheses and leading comma as in this example.
.EXAMPLE
	Remove-MSIApplications -Name 'Java 8 Update' -ExcludeFromUninstall (,('DisplayName', 'Java 8 Update 45', 'Contains'))
	Removes all versions of software that match the name "Java 8 Update"; however, it does not uninstall "Java 8 Update 45" of the software.
	NOTE: if only specifying a single row in the two-dimensional array, the array must have the extra parentheses and leading comma as in this example.
.EXAMPLE
	Remove-MSIApplications -Name 'Java 8 Update' -ExcludeFromUninstall
			('Is64BitApplication', $true, 'Exact'),
			('DisplayName', 'Java 8 Update 45', 'Exact'),
			('DisplayName', 'Java 8 Update 4*', 'WildCard'),
            ('DisplayName', 'Java \d Update \d{3}', 'RegEx'),
			('DisplayName', 'Java 8 Update', 'Contains')
	Removes all versions of software that match the name "Java 8 Update"; however, it does not uninstall 64-bit versions of the software, Update 45 of the software, or any Update that starts with 4.
.NOTES
	More reading on how to create arrays if having trouble with -FilterApplication or -ExcludeFromUninstall parameter: http://blogs.msdn.com/b/powershell/archive/2007/01/23/array-literals-in-powershell.aspx
.LINK
	http://psappdeploytoolkit.com
#>
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $true)]
		[ValidateNotNullorEmpty()]
		[string]$Name,
		[Parameter(Mandatory = $false)]
		[switch]$Exact = $false,
		[Parameter(Mandatory = $false)]
		[switch]$WildCard = $false,
		[Parameter(Mandatory = $false)]
		[Alias('Arguments')]
		[ValidateNotNullorEmpty()]
		[string]$Parameters,
		[Parameter(Mandatory = $false)]
		[ValidateNotNullorEmpty()]
		[string]$AddParameters,
		[Parameter(Mandatory = $false)]
		[ValidateNotNullorEmpty()]
		[array]$FilterApplication = @(@()),
		[Parameter(Mandatory = $false)]
		[ValidateNotNullorEmpty()]
		[array]$ExcludeFromUninstall = @(@()),
		[Parameter(Mandatory = $false)]
		[switch]$IncludeUpdatesAndHotfixes = $false,
		[Parameter(Mandatory = $false)]
		[ValidateNotNullorEmpty()]
		[string]$LoggingOptions,
		[Parameter(Mandatory = $false)]
		[Alias('LogName')]
		[string]$private:LogName,
		[Parameter(Mandatory = $false)]
		[ValidateNotNullorEmpty()]
		[switch]$PassThru = $false,
		[Parameter(Mandatory = $false)]
		[ValidateNotNullorEmpty()]
		[boolean]$ContinueOnError = $true
	)
	
	Begin
	{
		## Get the name of this function and write header
		[string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
		Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -CmdletBoundParameters $PSBoundParameters -Header
	}
	Process
	{
		## Build the hashtable with the options that will be passed to Get-InstalledApplication using splatting
		[hashtable]$GetInstalledApplicationSplat = @{ Name = $name }
		If ($Exact) { $GetInstalledApplicationSplat.Add('Exact', $Exact) }
		ElseIf ($WildCard) { $GetInstalledApplicationSplat.Add('WildCard', $WildCard) }
		If ($IncludeUpdatesAndHotfixes) { $GetInstalledApplicationSplat.Add('IncludeUpdatesAndHotfixes', $IncludeUpdatesAndHotfixes) }
		
		[psobject[]]$installedApplications = Get-InstalledApplication @GetInstalledApplicationSplat
		
		Write-Log -Message "Found [$($installedApplications.Count)] application(s) that matched the specified criteria [$Name]." -Source ${CmdletName}
		
		## Filter the results from Get-InstalledApplication
		[Collections.ArrayList]$removeMSIApplications = New-Object -TypeName 'System.Collections.ArrayList'
		If (($null -ne $installedApplications) -and ($installedApplications.Count))
		{
			ForEach ($installedApplication in $installedApplications)
			{
				If ($installedApplication.UninstallString -notmatch 'msiexec')
				{
					Write-Log -Message "Skipping removal of application [$($installedApplication.DisplayName)] because uninstall string [$($installedApplication.UninstallString)] does not match `"msiexec`"." -Severity 2 -Source ${CmdletName}
					Continue
				}
				If ([string]::IsNullOrEmpty($installedApplication.ProductCode))
				{
					Write-Log -Message "Skipping removal of application [$($installedApplication.DisplayName)] because unable to discover MSI ProductCode from application's registry Uninstall subkey [$($installedApplication.UninstallSubkey)]." -Severity 2 -Source ${CmdletName}
					Continue
				}
				
				#  Filter the results from Get-InstalledApplication to only those that should be uninstalled
				If (($null -ne $FilterApplication) -and ($FilterApplication.Count))
				{
					Write-Log -Message "Filter the results to only those that should be uninstalled as specified in parameter [-FilterApplication]." -Source ${CmdletName}
					[boolean]$addAppToRemoveList = $false
					ForEach ($Filter in $FilterApplication)
					{
						If ($Filter[2] -eq 'RegEx')
						{
							If ($installedApplication.($Filter[0]) -match $Filter[1])
							{
								[boolean]$addAppToRemoveList = $true
								Write-Log -Message "Preserve removal of application [$($installedApplication.DisplayName) $($installedApplication.Version)] because of regex match against [-FilterApplication] criteria." -Source ${CmdletName}
							}
						}
						ElseIf ($Filter[2] -eq 'Contains')
						{
							If ($installedApplication.($Filter[0]) -match [regex]::Escape($Filter[1]))
							{
								[boolean]$addAppToRemoveList = $true
								Write-Log -Message "Preserve removal of application [$($installedApplication.DisplayName) $($installedApplication.Version)] because of contains match against [-FilterApplication] criteria." -Source ${CmdletName}
							}
						}
						ElseIf ($Filter[2] -eq 'WildCard')
						{
							If ($installedApplication.($Filter[0]) -like $Filter[1])
							{
								[boolean]$addAppToRemoveList = $true
								Write-Log -Message "Preserve removal of application [$($installedApplication.DisplayName) $($installedApplication.Version)] because of wildcard match against [-FilterApplication] criteria." -Source ${CmdletName}
							}
						}
						ElseIf ($Filter[2] -eq 'Exact')
						{
							If ($installedApplication.($Filter[0]) -eq $Filter[1])
							{
								[boolean]$addAppToRemoveList = $true
								Write-Log -Message "Preserve removal of application [$($installedApplication.DisplayName) $($installedApplication.Version)] because of exact match against [-FilterApplication] criteria." -Source ${CmdletName}
							}
						}
					}
				}
				Else
				{
					[boolean]$addAppToRemoveList = $true
				}
				
				#  Filter the results from Get-InstalledApplication to remove those that should never be uninstalled
				If (($null -ne $ExcludeFromUninstall) -and ($ExcludeFromUninstall.Count))
				{
					ForEach ($Exclude in $ExcludeFromUninstall)
					{
						If ($Exclude[2] -eq 'RegEx')
						{
							If ($installedApplication.($Exclude[0]) -match $Exclude[1])
							{
								[boolean]$addAppToRemoveList = $false
								Write-Log -Message "Skipping removal of application [$($installedApplication.DisplayName) $($installedApplication.Version)] because of regex match against [-ExcludeFromUninstall] criteria." -Source ${CmdletName}
							}
						}
						ElseIf ($Exclude[2] -eq 'Contains')
						{
							If ($installedApplication.($Exclude[0]) -match [regex]::Escape($Exclude[1]))
							{
								[boolean]$addAppToRemoveList = $false
								Write-Log -Message "Skipping removal of application [$($installedApplication.DisplayName) $($installedApplication.Version)] because of contains match against [-ExcludeFromUninstall] criteria." -Source ${CmdletName}
							}
						}
						ElseIf ($Exclude[2] -eq 'WildCard')
						{
							If ($installedApplication.($Exclude[0]) -like $Exclude[1])
							{
								[boolean]$addAppToRemoveList = $false
								Write-Log -Message "Skipping removal of application [$($installedApplication.DisplayName) $($installedApplication.Version)] because of wildcard match against [-ExcludeFromUninstall] criteria." -Source ${CmdletName}
							}
						}
						ElseIf ($Exclude[2] -eq 'Exact')
						{
							If ($installedApplication.($Exclude[0]) -eq $Exclude[1])
							{
								[boolean]$addAppToRemoveList = $false
								Write-Log -Message "Skipping removal of application [$($installedApplication.DisplayName) $($installedApplication.Version)] because of exact match against [-ExcludeFromUninstall] criteria." -Source ${CmdletName}
							}
						}
					}
				}
				
				If ($addAppToRemoveList)
				{
					Write-Log -Message "Adding application to list for removal: [$($installedApplication.DisplayName) $($installedApplication.Version)]." -Source ${CmdletName}
					$removeMSIApplications.Add($installedApplication)
				}
			}
		}
		
		## Build the hashtable with the options that will be passed to Execute-MSI using splatting
		[hashtable]$ExecuteMSISplat = @{ Action = 'Uninstall'; Path = '' }
		If ($ContinueOnError) { $ExecuteMSISplat.Add('ContinueOnError', $ContinueOnError) }
		If ($Parameters) { $ExecuteMSISplat.Add('Parameters', $Parameters) }
		ElseIf ($AddParameters) { $ExecuteMSISplat.Add('AddParameters', $AddParameters) }
		If ($LoggingOptions) { $ExecuteMSISplat.Add('LoggingOptions', $LoggingOptions) }
		If ($LogName) { $ExecuteMSISplat.Add('LogName', $LogName) }
		If ($PassThru) { $ExecuteMSISplat.Add('PassThru', $PassThru) }
		If ($IncludeUpdatesAndHotfixes) { $ExecuteMSISplat.Add('IncludeUpdatesAndHotfixes', $IncludeUpdatesAndHotfixes) }
		
		If (($null -ne $removeMSIApplications) -and ($removeMSIApplications.Count))
		{
			ForEach ($removeMSIApplication in $removeMSIApplications)
			{
				Write-Log -Message "Remove application [$($removeMSIApplication.DisplayName) $($removeMSIApplication.Version)]." -Source ${CmdletName}
				$ExecuteMSISplat.Path = $removeMSIApplication.ProductCode
				If ($PassThru)
				{
					[psobject[]]$ExecuteResults += Execute-MSI @ExecuteMSISplat
				}
				Else
				{
					Execute-MSI @ExecuteMSISplat
				}
			}
		}
		Else
		{
			Write-Log -Message 'No applications found for removal. Continue...' -Source ${CmdletName}
		}
	}
	End
	{
		If ($PassThru) { Write-Output -InputObject $ExecuteResults }
		Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -Footer
	}
}
#endregion

#region Function New-Folder
Function New-Folder
{
<#
.SYNOPSIS
	Create a new folder.
.DESCRIPTION
	Create a new folder if it does not exist.
.PARAMETER Path
	Path to the new folder to create.
.PARAMETER ContinueOnError
	Continue if an error is encountered. Default is: $true.
.EXAMPLE
	New-Folder -Path "$envWinDir\System32"
.NOTES
.LINK
	http://psappdeploytoolkit.com
#>
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $true)]
		[ValidateNotNullorEmpty()]
		[string]$Path,
		[Parameter(Mandatory = $false)]
		[ValidateNotNullOrEmpty()]
		[boolean]$ContinueOnError = $true
	)
	
	Begin
	{
		## Get the name of this function and write header
		[string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
		Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -CmdletBoundParameters $PSBoundParameters -Header
	}
	Process
	{
		Try
		{
			If (-not (Test-Path -LiteralPath $Path -PathType 'Container'))
			{
				Write-Log -Message "Create folder [$Path]." -Source ${CmdletName}
				$null = New-Item -Path $Path -ItemType 'Directory' -ErrorAction 'Stop'
			}
			Else
			{
				Write-Log -Message "Folder [$Path] already exists." -Source ${CmdletName}
			}
		}
		Catch
		{
			Write-Log -Message "Failed to create folder [$Path]. `n$(Resolve-Error)" -Severity 3 -Source ${CmdletName}
			If (-not $ContinueOnError)
			{
				Throw "Failed to create folder [$Path]: $($_.Exception.Message)"
			}
		}
	}
	End
	{
		Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -Footer
	}
}
#endregion

#region Function Remove-Folder
Function Remove-Folder
{
<#
.SYNOPSIS
	Remove folder and files if they exist.
.DESCRIPTION
	Remove folder and all files recursively in a given path.
.PARAMETER Path
	Path to the folder to remove.
.PARAMETER ContinueOnError
	Continue if an error is encountered. Default is: $true.
.EXAMPLE
	Remove-Folder -Path "$envWinDir\Downloaded Program Files"
.NOTES
.LINK
	http://psappdeploytoolkit.com
#>
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $true)]
		[ValidateNotNullorEmpty()]
		[string]$Path,
		[Parameter(Mandatory = $false)]
		[ValidateNotNullOrEmpty()]
		[boolean]$ContinueOnError = $true
	)
	
	Begin
	{
		## Get the name of this function and write header
		[string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
		Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -CmdletBoundParameters $PSBoundParameters -Header
	}
	Process
	{
		If (Test-Path -LiteralPath $Path -PathType 'Container')
		{
			Try
			{
				Write-Log -Message "Delete folder [$path] recursively..." -Source ${CmdletName}
				Remove-Item -LiteralPath $Path -Force -Recurse -ErrorAction 'SilentlyContinue' -ErrorVariable '+ErrorRemoveFolder'
				If ($ErrorRemoveFolder)
				{
					Write-Log -Message "The following error(s) took place while deleting folder(s) and file(s) recursively from path [$path]. `n$(Resolve-Error -ErrorRecord $ErrorRemoveFolder)" -Severity 2 -Source ${CmdletName}
				}
			}
			Catch
			{
				Write-Log -Message "Failed to delete folder(s) and file(s) recursively from path [$path]. `n$(Resolve-Error)" -Severity 3 -Source ${CmdletName}
				If (-not $ContinueOnError)
				{
					Throw "Failed to delete folder(s) and file(s) recursively from path [$path]: $($_.Exception.Message)"
				}
			}
		}
		Else
		{
			Write-Log -Message "Folder [$Path] does not exists..." -Source ${CmdletName}
		}
	}
	End
	{
		Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -Footer
	}
}
#endregion

#region Function Remove-File
Function Remove-File
{
<#
.SYNOPSIS
	Removes one or more items from a given path on the filesystem.
.DESCRIPTION
	Removes one or more items from a given path on the filesystem.
.PARAMETER Path
	Specifies the path on the filesystem to be resolved. The value of Path will accept wildcards. Will accept an array of values.
.PARAMETER LiteralPath
	Specifies the path on the filesystem to be resolved. The value of LiteralPath is used exactly as it is typed; no characters are interpreted as wildcards. Will accept an array of values.
.PARAMETER Recurse
	Deletes the files in the specified location(s) and in all child items of the location(s).
.PARAMETER ContinueOnError
	Continue if an error is encountered. Default is: $true.
.EXAMPLE
	Remove-File -Path 'C:\Windows\Downloaded Program Files\Temp.inf'
.EXAMPLE
	Remove-File -LiteralPath 'C:\Windows\Downloaded Program Files' -Recurse
.NOTES
.LINK
	http://psappdeploytoolkit.com
#>
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $true, ParameterSetName = 'Path')]
		[ValidateNotNullorEmpty()]
		[string[]]$Path,
		[Parameter(Mandatory = $true, ParameterSetName = 'LiteralPath')]
		[ValidateNotNullorEmpty()]
		[string[]]$LiteralPath,
		[Parameter(Mandatory = $false)]
		[switch]$Recurse = $false,
		[Parameter(Mandatory = $false)]
		[ValidateNotNullOrEmpty()]
		[boolean]$ContinueOnError = $true
	)
	
	Begin
	{
		## Get the name of this function and write header
		[string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
		Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -CmdletBoundParameters $PSBoundParameters -Header
	}
	Process
	{
		## Build hashtable of parameters/value pairs to be passed to Remove-Item cmdlet
		[hashtable]$RemoveFileSplat = @{
			'Recurse'	    = $Recurse
			'Force'		    = $true
			'ErrorVariable' = '+ErrorRemoveItem'
		}
		If ($ContinueOnError)
		{
			$RemoveFileSplat.Add('ErrorAction', 'SilentlyContinue')
		}
		Else
		{
			$RemoveFileSplat.Add('ErrorAction', 'Stop')
		}
		
		## Resolve the specified path, if the path does not exist, display a warning instead of an error
		If ($PSCmdlet.ParameterSetName -eq 'Path') { [string[]]$SpecifiedPath = $Path }
		Else { [string[]]$SpecifiedPath = $LiteralPath }
		ForEach ($Item in $SpecifiedPath)
		{
			Try
			{
				If ($PSCmdlet.ParameterSetName -eq 'Path')
				{
					[string[]]$ResolvedPath += Resolve-Path -Path $Item -ErrorAction 'Stop' | Where-Object { $_.Path } | Select-Object -ExpandProperty 'Path' -ErrorAction 'Stop'
				}
				Else
				{
					[string[]]$ResolvedPath += Resolve-Path -LiteralPath $Item -ErrorAction 'Stop' | Where-Object { $_.Path } | Select-Object -ExpandProperty 'Path' -ErrorAction 'Stop'
				}
			}
			Catch [System.Management.Automation.ItemNotFoundException] {
				Write-Log -Message "Unable to resolve file(s) for deletion in path [$Item] because path does not exist." -Severity 2 -Source ${CmdletName}
			}
			Catch
			{
				Write-Log -Message "Failed to resolve file(s) for deletion in path [$Item]. `n$(Resolve-Error)" -Severity 3 -Source ${CmdletName}
				If (-not $ContinueOnError)
				{
					Throw "Failed to resolve file(s) for deletion in path [$Item]: $($_.Exception.Message)"
				}
			}
		}
		
		## Delete specified path if it was successfully resolved
		If ($ResolvedPath)
		{
			ForEach ($Item in $ResolvedPath)
			{
				Try
				{
					If (($Recurse) -and (Test-Path -LiteralPath $Item -PathType 'Container'))
					{
						Write-Log -Message "Delete file(s) recursively in path [$Item]..." -Source ${CmdletName}
					}
					ElseIf ((-not $Recurse) -and (Test-Path -LiteralPath $Item -PathType 'Container'))
					{
						Write-Log -Message "Skipping folder [$Item] because the Recurse switch was not specified"
						Continue
					}
					Else
					{
						Write-Log -Message "Delete file in path [$Item]..." -Source ${CmdletName}
					}
					$null = Remove-Item @RemoveFileSplat -LiteralPath $Item
				}
				Catch
				{
					Write-Log -Message "Failed to delete file(s) in path [$Item]. `n$(Resolve-Error)" -Severity 3 -Source ${CmdletName}
					If (-not $ContinueOnError)
					{
						Throw "Failed to delete file(s) in path [$Item]: $($_.Exception.Message)"
					}
				}
			}
		}
		
		If ($ErrorRemoveItem)
		{
			Write-Log -Message "The following error(s) took place while removing file(s) in path [$SpecifiedPath]. `n$(Resolve-Error -ErrorRecord $ErrorRemoveItem)" -Severity 2 -Source ${CmdletName}
		}
	}
	End
	{
		Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -Footer
	}
}
#endregion

#region Function Test-RegistryValue
Function Test-RegistryValue
{
<#
.SYNOPSIS
	Test if a registry value exists.
.DESCRIPTION
	Checks a registry key path to see if it has a value with a given name. Can correctly handle cases where a value simply has an empty or null value.
.DEPENDENCIES
	Convert-RegistryPath
.PARAMETER Key
	Path of the registry key.
.PARAMETER Value
	Specify the registry key value to check the existence of.
.PARAMETER SID
	The security identifier (SID) for a user. Specifying this parameter will convert a HKEY_CURRENT_USER registry key to the HKEY_USERS\$SID format.
	Specify this parameter from the Invoke-HKCURegistrySettingsForAllUsers function to read/edit HKCU registry settings for all users on the system.
.EXAMPLE
	Test-RegistryValue -Key 'HKLM:SYSTEM\CurrentControlSet\Control\Session Manager' -Value 'PendingFileRenameOperations'
.NOTES
	To test if registry key exists, use Test-Path function like so:
	Test-Path -Path $Key -PathType 'Container'
.LINK
	http://psappdeploytoolkit.com
#>
	Param (
		[Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
		[ValidateNotNullOrEmpty()]
		$Key,
		[Parameter(Mandatory = $true, Position = 1)]
		[ValidateNotNullOrEmpty()]
		$Value,
		[Parameter(Mandatory = $false, Position = 2)]
		[ValidateNotNullorEmpty()]
		[string]$SID,
		[Switch]$Silent
	)
	
	Begin
	{
		## Get the name of this function and write header
		[string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
		Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -CmdletBoundParameters $PSBoundParameters -Header
	}
	Process
	{
		## If the SID variable is specified, then convert all HKEY_CURRENT_USER key's to HKEY_USERS\$SID
		Try
		{
			# Splat Convert-RegistryPath Params
			$convertRegPathSplat = @{
				'Key' = $Key
			}
			if ($Silent) { $convertRegPathSplat.Add('Silent',$true) }
			If ($PSBoundParameters.ContainsKey('SID'))
			{
				$convertRegPathSplat.Add('SID', $SID)
				[string]$Key = Convert-RegistryPath @convertRegPathSplat
			}
			Else
			{
				[string]$Key = Convert-RegistryPath @convertRegPathSplat
			}
		}
		Catch
		{
			Throw
		}
		[boolean]$IsRegistryValueExists = $false
		Try
		{
			If (Test-Path -LiteralPath $Key -ErrorAction 'Stop')
			{
				[string[]]$PathProperties = Get-Item -LiteralPath $Key -ErrorAction 'Stop' | Select-Object -ExpandProperty 'Property' -ErrorAction 'Stop'
				If ($PathProperties -contains $Value) { $IsRegistryValueExists = $true }
			}
		}
		Catch { }
		
		If ($IsRegistryValueExists)
		{
			if (-not $Silent) { Write-Log -Message "Registry key value [$Key] [$Value] does exist." -Source ${CmdletName} }
		}
		Else
		{
			if (-not $Silent) { Write-Log -Message "Registry key value [$Key] [$Value] does not exist." -Source ${CmdletName} }
		}
		Write-Output -InputObject $IsRegistryValueExists
	}
	End
	{
		Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -Footer
	}
}
#endregion

#region Function Set-RegistryKey
Function Set-RegistryKey
{
<#
.SYNOPSIS
	Creates a registry key name, value, and value data; it sets the same if it already exists.
.DESCRIPTION
	Creates a registry key name, value, and value data; it sets the same if it already exists.
.PARAMETER Key
	The registry key path.
.PARAMETER Name
	The value name.
.PARAMETER Value
	The value data.
.PARAMETER Type
	The type of registry value to create or set. Options: 'Binary','DWord','ExpandString','MultiString','None','QWord','String','Unknown'. Default: String.
	Dword should be specified as a decimal.
.PARAMETER SID
	The security identifier (SID) for a user. Specifying this parameter will convert a HKEY_CURRENT_USER registry key to the HKEY_USERS\$SID format.
	Specify this parameter from the Invoke-HKCURegistrySettingsForAllUsers function to read/edit HKCU registry settings for all users on the system.
.PARAMETER ContinueOnError
	Continue if an error is encountered. Default is: $true.
.EXAMPLE
	Set-RegistryKey -Key $blockedAppPath -Name 'Debugger' -Value $blockedAppDebuggerValue
.EXAMPLE
	Set-RegistryKey -Key 'HKEY_LOCAL_MACHINE\SOFTWARE' -Name 'Application' -Type 'Dword' -Value '1'
.EXAMPLE
	Set-RegistryKey -Key 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce' -Name 'Debugger' -Value $blockedAppDebuggerValue -Type String
.EXAMPLE
	Set-RegistryKey -Key 'HKCU\Software\Microsoft\Example' -Name 'Data' -Value (0x01,0x01,0x01,0x01,0x01,0x01,0x01,0x01,0x01,0x01,0x01,0x01,0x02,0x01,0x01,0x01,0x01,0x01,0x01,0x01,0x02,0x01,0x01,0x01,0x01,0x01,0x01,0x01,0x00,0x01,0x01,0x01,0x02,0x02,0x02) -Type 'Binary'
.EXAMPLE
    Set-RegistryKey -Key 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Example' -Value '(Default)'
.NOTES
.LINK
	http://psappdeploytoolkit.com
#>
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $true)]
		[ValidateNotNullorEmpty()]
		[string]$Key,
		[Parameter(Mandatory = $false)]
		[ValidateNotNullOrEmpty()]
		[string]$Name,
		[Parameter(Mandatory = $false)]
		$Value,
		[Parameter(Mandatory = $false)]
		[ValidateSet('Binary', 'DWord', 'ExpandString', 'MultiString', 'None', 'QWord', 'String', 'Unknown')]
		[Microsoft.Win32.RegistryValueKind]$Type = 'String',
		[Parameter(Mandatory = $false)]
		[ValidateNotNullorEmpty()]
		[string]$SID,
		[Parameter(Mandatory = $false)]
		[ValidateNotNullOrEmpty()]
		[boolean]$ContinueOnError = $true
	)
	
	Begin
	{
		## Get the name of this function and write header
		[string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
		Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -CmdletBoundParameters $PSBoundParameters -Header
	}
	Process
	{
		Try
		{
			[string]$RegistryValueWriteAction = 'set'
			
			## If the SID variable is specified, then convert all HKEY_CURRENT_USER key's to HKEY_USERS\$SID
			If ($PSBoundParameters.ContainsKey('SID'))
			{
				[string]$key = Convert-RegistryPath -Key $key -SID $SID
			}
			Else
			{
				[string]$key = Convert-RegistryPath -Key $key
			}
			
			## Create registry key if it doesn't exist
			If (-not (Test-Path -LiteralPath $key -ErrorAction 'Stop'))
			{
				Try
				{
					Write-Log -Message "Create registry key [$key]." -Source ${CmdletName}
					# No forward slash found in Key. Use New-Item cmdlet to create registry key
					If ((($Key -split '/').Count - 1) -eq 0)
					{
						$null = New-Item -Path $key -ItemType 'Registry' -Force -ErrorAction 'Stop'
					}
					# Forward slash was found in Key. Use REG.exe ADD to create registry key
					Else
					{
						[string]$CreateRegkeyResult = & reg.exe Add "$($Key.Substring($Key.IndexOf('::') + 2))"
						If ($global:LastExitCode -ne 0)
						{
							Throw "Failed to create registry key [$Key]"
						}
					}
				}
				Catch
				{
					Throw
				}
			}
			
			If ($Name)
			{
				## Set registry value if it doesn't exist
				If (-not (Get-ItemProperty -LiteralPath $key -Name $Name -ErrorAction 'SilentlyContinue'))
				{
					Write-Log -Message "Set registry key value: [$key] [$name = $value]." -Source ${CmdletName}
					$null = New-ItemProperty -LiteralPath $key -Name $name -Value $value -PropertyType $Type -ErrorAction 'Stop'
				}
				## Update registry value if it does exist
				Else
				{
					[string]$RegistryValueWriteAction = 'update'
					If ($Name -eq '(Default)')
					{
						## Set Default registry key value with the following workaround, because Set-ItemProperty contains a bug and cannot set Default registry key value
						$null = $(Get-Item -LiteralPath $key -ErrorAction 'Stop').OpenSubKey('', 'ReadWriteSubTree').SetValue($null, $value)
					}
					Else
					{
						Write-Log -Message "Update registry key value: [$key] [$name = $value]." -Source ${CmdletName}
						$null = Set-ItemProperty -LiteralPath $key -Name $name -Value $value -ErrorAction 'Stop'
					}
				}
			}
		}
		Catch
		{
			If ($Name)
			{
				Write-Log -Message "Failed to $RegistryValueWriteAction value [$value] for registry key [$key] [$name]. `n$(Resolve-Error)" -Severity 3 -Source ${CmdletName}
				If (-not $ContinueOnError)
				{
					Throw "Failed to $RegistryValueWriteAction value [$value] for registry key [$key] [$name]: $($_.Exception.Message)"
				}
			}
			Else
			{
				Write-Log -Message "Failed to set registry key [$key]. `n$(Resolve-Error)" -Severity 3 -Source ${CmdletName}
				If (-not $ContinueOnError)
				{
					Throw "Failed to set registry key [$key]: $($_.Exception.Message)"
				}
			}
		}
	}
	End
	{
		Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -Footer
	}
}
#endregion

#region Function Remove-RegistryKey
Function Remove-RegistryKey
{
<#
.SYNOPSIS
	Deletes the specified registry key or value.
.DESCRIPTION
	Deletes the specified registry key or value.
.DEPENDENCIES
	Resolve-Error
.PARAMETER Key
	Path of the registry key to delete.
.PARAMETER Name
	Name of the registry value to delete.
.PARAMETER Recurse
	Delete registry key recursively.
.PARAMETER SID
	The security identifier (SID) for a user. Specifying this parameter will convert a HKEY_CURRENT_USER registry key to the HKEY_USERS\$SID format.
	Specify this parameter from the Invoke-HKCURegistrySettingsForAllUsers function to read/edit HKCU registry settings for all users on the system.
.PARAMETER ContinueOnError
	Continue if an error is encountered. Default is: $true.
.EXAMPLE
	Remove-RegistryKey -Key 'HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\RunOnce'
.EXAMPLE
	Remove-RegistryKey -Key 'HKLM:SOFTWARE\Microsoft\Windows\CurrentVersion\Run' -Name 'RunAppInstall'
.NOTES
.LINK
	http://psappdeploytoolkit.com
#>
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $true)]
		[ValidateNotNullorEmpty()]
		[string]$Key,
		[Parameter(Mandatory = $false)]
		[ValidateNotNullOrEmpty()]
		[string]$Name,
		[Parameter(Mandatory = $false)]
		[switch]$Recurse,
		[Parameter(Mandatory = $false)]
		[ValidateNotNullorEmpty()]
		[string]$SID,
		[Parameter(Mandatory = $false)]
		[ValidateNotNullOrEmpty()]
		[boolean]$ContinueOnError = $true
	)
	
	Begin
	{
		## Get the name of this function and write header
		[string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
		Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -CmdletBoundParameters $PSBoundParameters -Header
	}
	Process
	{
		Try
		{
			## If the SID variable is specified, then convert all HKEY_CURRENT_USER key's to HKEY_USERS\$SID
			If ($PSBoundParameters.ContainsKey('SID'))
			{
				[string]$Key = Convert-RegistryPath -Key $Key -SID $SID
			}
			Else
			{
				[string]$Key = Convert-RegistryPath -Key $Key
			}
			
			If (-not ($Name))
			{
				If (Test-Path -LiteralPath $Key -ErrorAction 'Stop')
				{
					If ($Recurse)
					{
						Write-Log -Message "Delete registry key recursively [$Key]." -Source ${CmdletName}
						$null = Remove-Item -LiteralPath $Key -Force -Recurse -ErrorAction 'Stop'
					}
					Else
					{
						If ($null -eq (Get-ChildItem -LiteralPath $Key -ErrorAction 'Stop'))
						{
							## Check if there are subkeys of $Key, if so, executing Remove-Item will hang. Avoiding this with Get-ChildItem.
							Write-Log -Message "Delete registry key [$Key]." -Source ${CmdletName}
							$null = Remove-Item -LiteralPath $Key -Force -ErrorAction 'Stop'
						}
						Else
						{
							Throw "Unable to delete child key(s) of [$Key] without [-Recurse] switch."
						}
					}
				}
				Else
				{
					Write-Log -Message "Unable to delete registry key [$Key] because it does not exist." -Severity 2 -Source ${CmdletName}
				}
			}
			Else
			{
				If (Test-Path -LiteralPath $Key -ErrorAction 'Stop')
				{
					Write-Log -Message "Delete registry value [$Key] [$Name]." -Source ${CmdletName}
					
					If ($Name -eq '(Default)')
					{
						## Remove (Default) registry key value with the following workaround because Remove-ItemProperty cannot remove the (Default) registry key value
						$null = (Get-Item -LiteralPath $Key -ErrorAction 'Stop').OpenSubKey('', 'ReadWriteSubTree').DeleteValue('')
					}
					Else
					{
						$null = Remove-ItemProperty -LiteralPath $Key -Name $Name -Force -ErrorAction 'Stop'
					}
				}
				Else
				{
					Write-Log -Message "Unable to delete registry value [$Key] [$Name] because registry key does not exist." -Severity 2 -Source ${CmdletName}
				}
			}
		}
		Catch [System.Management.Automation.PSArgumentException] {
			Write-Log -Message "Unable to delete registry value [$Key] [$Name] because it does not exist." -Severity 2 -Source ${CmdletName}
		}
		Catch
		{
			If (-not ($Name))
			{
				Write-Log -Message "Failed to delete registry key [$Key]. `n$(Resolve-Error)" -Severity 3 -Source ${CmdletName}
				If (-not $ContinueOnError)
				{
					Throw "Failed to delete registry key [$Key]: $($_.Exception.Message)"
				}
			}
			Else
			{
				Write-Log -Message "Failed to delete registry value [$Key] [$Name]. `n$(Resolve-Error)" -Severity 3 -Source ${CmdletName}
				If (-not $ContinueOnError)
				{
					Throw "Failed to delete registry value [$Key] [$Name]: $($_.Exception.Message)"
				}
			}
		}
	}
	End
	{
		Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -Footer
	}
}
#endregion

#region Function Get-HardwarePlatform
Function Get-HardwarePlatform
{
<#
.SYNOPSIS
	Retrieves information about the hardware platform (physical or virtual)
.DESCRIPTION
	Retrieves information about the hardware platform (physical or virtual)
.DEPENDENCIES
	Resolve-Error
.PARAMETER ContinueOnError
	Continue if an error is encountered. Default is: $true.
.EXAMPLE
	Get-HardwarePlatform
.NOTES
.LINK
	http://psappdeploytoolkit.com
#>
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $false)]
		[ValidateNotNullorEmpty()]
		[boolean]$ContinueOnError = $true
	)
	
	Begin
	{
		## Get the name of this function and write header
		[string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
		Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -CmdletBoundParameters $PSBoundParameters -Header
	}
	Process
	{
		Try
		{
			Write-Log -Message 'Retrieve hardware platform information.' -Source ${CmdletName}
			$hwBios = Get-WmiObject -Class 'Win32_BIOS' -ErrorAction 'Stop' | Select-Object -Property 'Version', 'SerialNumber'
			$hwMakeModel = Get-WMIObject -Class 'Win32_ComputerSystem' -ErrorAction 'Stop' | Select-Object -Property 'Model', 'Manufacturer'
			
			If ($hwBIOS.Version -match 'VRTUAL') { $hwType = 'Virtual:Hyper-V' }
			ElseIf ($hwBIOS.Version -match 'A M I') { $hwType = 'Virtual:Virtual PC' }
			ElseIf ($hwBIOS.Version -like '*Xen*') { $hwType = 'Virtual:Xen' }
			ElseIf ($hwBIOS.SerialNumber -like '*VMware*') { $hwType = 'Virtual:VMWare' }
			ElseIf (($hwMakeModel.Manufacturer -like '*Microsoft*') -and ($hwMakeModel.Model -notlike '*Surface*')) { $hwType = 'Virtual:Hyper-V' }
			ElseIf ($hwMakeModel.Manufacturer -like '*VMWare*') { $hwType = 'Virtual:VMWare' }
			ElseIf ($hwMakeModel.Model -like '*Virtual*') { $hwType = 'Virtual' }
			Else { $hwType = 'Physical' }
			
			Write-Output -InputObject $hwType
		}
		Catch
		{
			Write-Log -Message "Failed to retrieve hardware platform information. `n$(Resolve-Error)" -Severity 3 -Source ${CmdletName}
			If (-not $ContinueOnError)
			{
				Throw "Failed to retrieve hardware platform information: $($_.Exception.Message)"
			}
		}
	}
	End
	{
		Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -Footer
	}
}
#endregion

#region Function Get-FreeDiskSpace
Function Get-FreeDiskSpace
{
<#
.SYNOPSIS
	Retrieves the free disk space in MB on a particular drive (defaults to system drive)
.DESCRIPTION
	Retrieves the free disk space in MB on a particular drive (defaults to system drive)
.DEPENDENCIES
	Resolve-Error
.PARAMETER Drive
	Drive to check free disk space on
.PARAMETER ContinueOnError
	Continue if an error is encountered. Default is: $true.
.EXAMPLE
	Get-FreeDiskSpace -Drive 'C:'
.NOTES
.LINK
	http://psappdeploytoolkit.com
#>
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $false)]
		[ValidateNotNullorEmpty()]
		[string]$Drive = $envSystemDrive,
		[Parameter(Mandatory = $false)]
		[ValidateNotNullorEmpty()]
		[boolean]$ContinueOnError = $true
	)
	
	Begin
	{
		## Get the name of this function and write header
		[string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
		Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -CmdletBoundParameters $PSBoundParameters -Header
	}
	Process
	{
		Try
		{
			Write-Log -Message "Retrieve free disk space for drive [$Drive]." -Source ${CmdletName}
			$disk = Get-WmiObject -Class 'Win32_LogicalDisk' -Filter "DeviceID='$Drive'" -ErrorAction 'Stop'
			[double]$freeDiskSpace = [math]::Round($disk.FreeSpace / 1MB)
			
			Write-Log -Message "Free disk space for drive [$Drive]: [$freeDiskSpace MB]." -Source ${CmdletName}
			Write-Output -InputObject $freeDiskSpace
		}
		Catch
		{
			Write-Log -Message "Failed to retrieve free disk space for drive [$Drive]. `n$(Resolve-Error)" -Severity 3 -Source ${CmdletName}
			If (-not $ContinueOnError)
			{
				Throw "Failed to retrieve free disk space for drive [$Drive]: $($_.Exception.Message)"
			}
		}
	}
	End
	{
		Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -Footer
	}
}
#endregion

#region Function Update-Desktop
Function Update-Desktop
{
<#
.SYNOPSIS
	Refresh the Windows Explorer Shell, which causes the desktop icons and the environment variables to be reloaded.
.DESCRIPTION
	Refresh the Windows Explorer Shell, which causes the desktop icons and the environment variables to be reloaded.
.PARAMETER ContinueOnError
	Continue if an error is encountered. Default is: $true.
.EXAMPLE
	Update-Desktop
.NOTES
.LINK
	http://psappdeploytoolkit.com
#>
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $false)]
		[ValidateNotNullOrEmpty()]
		[boolean]$ContinueOnError = $true
	)
	
	Begin
	{
		## Get the name of this function and write header
		[string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
		Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -CmdletBoundParameters $PSBoundParameters -Header
	}
	Process
	{
		Try
		{
			Write-Log -Message 'Refresh the Desktop and the Windows Explorer environment process block.' -Source ${CmdletName}
			[PSADT.Explorer]::RefreshDesktopAndEnvironmentVariables()
		}
		Catch
		{
			Write-Log -Message "Failed to refresh the Desktop and the Windows Explorer environment process block. `n$(Resolve-Error)" -Severity 3 -Source ${CmdletName}
			If (-not $ContinueOnError)
			{
				Throw "Failed to refresh the Desktop and the Windows Explorer environment process block: $($_.Exception.Message)"
			}
		}
	}
	End
	{
		Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -Footer
	}
}
Set-Alias -Name 'Refresh-Desktop' -Value 'Update-Desktop' -Scope 'Script' -Force -ErrorAction 'SilentlyContinue'
#endregion

#region Function Get-LoggedOnUser
Function Get-LoggedOnUser
{
<#
.SYNOPSIS
	Get session details for all local and RDP logged on users.
.DESCRIPTION
	Get session details for all local and RDP logged on users using Win32 APIs. Get the following session details:
	 NTAccount, SID, UserName, DomainName, SessionId, SessionName, ConnectState, IsCurrentSession, IsConsoleSession, IsUserSession, IsActiveUserSession
	 IsRdpSession, IsLocalAdmin, LogonTime, IdleTime, DisconnectTime, ClientName, ClientProtocolType, ClientDirectory, ClientBuildNumber
.DEPENDENCIES
	Resolve-Error
.EXAMPLE
	Get-LoggedOnUser
.NOTES
	Description of ConnectState property:
	Value		 Description
	-----		 -----------
	Active		 A user is logged on to the session.
	ConnectQuery The session is in the process of connecting to a client.
	Connected	 A client is connected to the session.
	Disconnected The session is active, but the client has disconnected from it.
	Down		 The session is down due to an error.
	Idle		 The session is waiting for a client to connect.
	Initializing The session is initializing.
	Listening 	 The session is listening for connections.
	Reset		 The session is being reset.
	Shadowing	 This session is shadowing another session.

	Description of IsActiveUserSession property:
	If a console user exists, then that will be the active user session.
	If no console user exists but users are logged in, such as on terminal servers, then the first logged-in non-console user that is either 'Active' or 'Connected' is the active user.

	Description of IsRdpSession property:
	Gets a value indicating whether the user is associated with an RDP client session.
.LINK
	http://psappdeploytoolkit.com
#>
	[CmdletBinding()]
	Param (
	)
	
	Begin
	{
		## Get the name of this function and write header
		[string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
		Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -CmdletBoundParameters $PSBoundParameters -Header
	}
	Process
	{
		Try
		{
			Write-Log -Message 'Get session information for all logged on users.' -Source ${CmdletName}
			$LoggedOnUser = ([PSADT.QueryUser]::GetUserSessionInfo("$env:ComputerName")).NTAccount
			Write-Log -Message "Logged on user = $LoggedOnUser" -Source ${CmdletName}
			Write-Output -InputObject ([PSADT.QueryUser]::GetUserSessionInfo("$env:ComputerName"))
		}
		Catch
		{
			Write-Log -Message "Failed to get session information for all logged on users. `n$(Resolve-Error)" -Severity 3 -Source ${CmdletName}
		}
	}
	End
	{
		Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -Footer
	}
}
#endregion

#region Function Update-GroupPolicy
Function Update-GroupPolicy
{
<#
.SYNOPSIS
	Performs a gpupdate command to refresh Group Policies on the local machine.
.DESCRIPTION
	Performs a gpupdate command to refresh Group Policies on the local machine.
.PARAMETER ContinueOnError
	Continue if an error is encountered. Default is: $true.
.EXAMPLE
	Update-GroupPolicy
.NOTES
.LINK
	http://psappdeploytoolkit.com
#>
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $false)]
		[ValidateNotNullorEmpty()]
		[boolean]$ContinueOnError = $true
	)
	
	Begin
	{
		## Get the name of this function and write header
		[string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
		Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -CmdletBoundParameters $PSBoundParameters -Header
	}
	Process
	{
		[string[]]$GPUpdateCmds = '/C echo N | gpupdate.exe /Target:Computer /Force', '/C echo N | gpupdate.exe /Target:User /Force'
		[int32]$InstallCount = 0
		ForEach ($GPUpdateCmd in $GPUpdateCmds)
		{
			Try
			{
				If ($InstallCount -eq 0)
				{
					[string]$InstallMsg = 'Update Group Policies for the Machine'
					Write-Log -Message "$($InstallMsg)..." -Source ${CmdletName}
				}
				Else
				{
					[string]$InstallMsg = 'Update Group Policies for the User'
					Write-Log -Message "$($InstallMsg)..." -Source ${CmdletName}
				}
				[psobject]$ExecuteResult = Execute-Process -Path "$envWindir\system32\cmd.exe" -Parameters $GPUpdateCmd -WindowStyle 'Hidden' -PassThru
				
				If ($ExecuteResult.ExitCode -ne 0)
				{
					If ($ExecuteResult.ExitCode -eq 60002)
					{
						Throw "Execute-Process function failed with exit code [$($ExecuteResult.ExitCode)]."
					}
					Else
					{
						Throw "gpupdate.exe failed with exit code [$($ExecuteResult.ExitCode)]."
					}
				}
				$InstallCount++
			}
			Catch
			{
				Write-Log -Message "Failed to $($InstallMsg). `n$(Resolve-Error)" -Severity 3 -Source ${CmdletName}
				If (-not $ContinueOnError)
				{
					Throw "Failed to $($InstallMsg): $($_.Exception.Message)"
				}
				Continue
			}
		}
	}
	End
	{
		Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -Footer
	}
}
#endregion

#region Function CheckStopProcesses
function Check-StopProcesses
{
	
	<#
	.SYNOPSIS
		Will check if to determine if processes should be stopped

	.PARAMETER PKGR_MSI_GUID
		Packager supplied GUID of application

	.PARAMETER PKGR_MSI_ARPNAME
		Packager supplied add/remove program name of application

	.PARAMETER PKGR_MSI_ARPVERSION
		Packager supplied add/remove program version of application

	.PARAMETER PKGR_APPDISPLAYNAME
		Packager supplied DisplayName to present to user in Prompt Screen if necessary

	.PARAMETER PKGR_LogPath
		Path to log file

	.PARAMETER PKGR_STOPREQUIREDPROCESSES
		Packager supplied list of processes to be stopped before installation

	.EXAMPLE
		CheckStopProcesses -PKGR_APPDISPLAYNAME $PKGR_APPDISPLAYNAME -PKGR_LOGPATH $PKGR_LOGPATH -PKGR_MSI_ARPNAME $PKGR_MSI_ARPNAME -PKGR_MSI_ARPVERSION $PKGR_MSI_ARPVERSION -PKGR_MSI_GUID $PKGR_MSI_GUID -PKGR_STOPREQUIREDPROCESSES $PKGR_STOPREQUIREDPROCESSES
	#>
	
	PARAM (
		[Parameter(Mandatory = $true)]
		[string]$appName,
		[Parameter(Mandatory = $true)]
		[string]$appVersion,
		[Parameter(Mandatory = $true)]
		[string]$appStopRequiredProcesses
	)
	
	# prompt user to accept reboot
	if ($Commandline.ToLower().Contains("/reboot"))
	{
		Show-InstallInformation_psf -AppName $appName -AppVersion $appVersion -appStopRequiredProcesses $appStopRequiredProcesses -processlist $OpenProcessesPrompt		
	}
	# prompt user to close apps
	if (($appStopRequiredProcesses) -and (!($Commandline.ToLower().Contains("/reboot"))))
	{
		$FRBOpenProcessesToCheck = ConvertStringTo-FRBProcess -strOpenProcess $appStopRequiredProcesses
		$OpenProcessesPrompt = $FRBOpenProcessesToCheck | Get-FRBOpenProcess -DoPrompt
		if ($OpenProcessesPrompt)
		{
			Show-InstallInformation_psf -AppName $appName -AppVersion $appVersion -appStopRequiredProcesses $appStopRequiredProcesses -processlist $OpenProcessesPrompt			
		}
		
		
	}
}
#endregion

#region Function Remove-ExistingApp
function Remove-ExistingApp
{
	PARAM (
		[Parameter(Mandatory = $true)]
		[string]$appName
	)
	## Uninstall previous versions
	Write-Log -Message "Checking for previous versions" -LogType 'CMTrace'
	$arpApps = Get-InstalledApplication -Name $appName
	Foreach ($arpApp in $arpApps)
	{
		$removeDisplayName = $arpApp | select -expand DisplayName
		$removeDisplayVersion = $arpApp | select -expand DisplayVersion
		Write-Log -Message "Found version: $removeDisplayVersion" -LogType 'CMTrace'
		# We only want to remove previous versions if they are older than the current version
		if ($removeDisplayVersion -lt $appVersion)
		{
			if (($arpApp | select -expand UninstallString).ToLower() -like "*msiexec.exe*")
			{
				$removeGUID = $arpApp | select -expand ProductCode
				Write-Log -Message "Removing previous version MSI $removeDisplayName $removeDisplayVersion" -LogType 'CMTrace'
				Execute-MSI -Action 'Uninstall' -Path $removeGUID -LogName "$removeDisplayName`-$removeDisplayVersion"
			}
			Else
			{
				# Customize this section based on the UninstallString entry of the Uninstall registry key
				$UninstallString = $arpApp | select -expand UninstallString
				$UninstallCommand, $UninstallArgs = $UninstallString.split('/')
				$UninstallCommand = $UninstallCommand.replace('"', '')
				$UninstallCommand = $UninstallCommand.trim()
				Write-Log -Message "Removing previous version SETUP $removeDisplayName $removeDisplayVersion" -LogType 'CMTrace'
				Execute-Process -Path $UninstallCommand -Parameters "/uninstall /quiet /norestart /log `"$configToolkitLogDir\SETUP_UNINST_$removeDisplayName`-$removeDisplayVersion.log`"" -WindowStyle 'Hidden'
			}
		}
	}
}
#endregion

#region Function Set-ARPEntry

function Set-ARPEntry
{
	<#
.SYNOPSIS
	Adds or removes an Add-Remove Programs (ARP) entry.
.DESCRIPTION
	Adds or removes an ARP entry for a given program in x64, x86, or User context. The cmdlet can be used alone to apply default values pulled from the wrapper or multiple parameters can be used to customize certain keys. 
    An MSI can also be used to pull information such as application Name, Version, Vendor, and GUID.
.PARAMETER Action
    This controls whether an uninstall key is created or removed. DEFAULT is set to 'Add'.
.PARAMETER Name
	This controls the entry name of the Application (i.e. Application Name or GUID).
.PARAMETER Context
    This sets where the registry key will be installed.
.PARAMETER MSIPath
	Path to an MSI file which provides the application Name, Version, Vendor, and Product Code (GUID) information.
.PARAMETER InstallLocation
    Path to the location where the program files will reside.
.PARAMETER IcoPath
    Path to the ICO or EXE file to provide an icon image for the ARP entry.
.PARAMETER UninstallString
    Uninstall command. Default setting is "$scriptPath\Install.exe /uninstall".
.EXAMPLE
	Set-ARPEntry
	In this example, an ARP entry is created with default settings. The entry will have no Display Icon, no Install Location, and will be applied in x64 bit context.
.EXAMPLE
	Set-ARPEntry -Name GUID -Contect User -IcoPath "$env:ProgramFiles\7-zip\7z.exe" -InstallLocation "$env:ProgramFiles\7-zip"
	In this example, an ARP entry is created in User context, using the GUID provided, with full details and will diplay an icon that mimics the EXE file icon. Because of the context chosen, this entry will only be viewable by the user who installed the application.
.EXAMPLE
    Set-ARPEntry -Action Remove
    In this example, an ARP entry containing ($appName + " " + $appVersion) is removed from the x64 bit registry location.
.EXAMPLE
    Set-ARPEntry -Action Remove -Name GUID -Context System-32
    In this example, an ARP entry matching the given GUID is removed from the 32-bit registry location.
.EXAMPLE
	Set-ARPEntry -Name GUID -MSIPath 'C:\Temp\Test.msi'
	In this example, an ARP entry is created with details (GUID,Name,Version,Vendor) received from the MSI provided.
.NOTES
	When selecting Remove in the Action parameter, it is important to match other parameters of the corresponding Add cmdlet (i.e. Name, MSIPath, Context). This is to ensure you're pointing the cmdlet to the correct location to remove the correct key.
.LINK
	http://psappdeploytoolkit.com
#>
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $false)]
		[ValidateSet("Add", "Remove")]
		[string]$Action = 'Add',
		[Parameter(Mandatory = $false)]
		[ValidateSet("Default", "GUID")]
		[string]$Name = 'Default',
		[Parameter(Mandatory = $false)]
		[ValidateSet("System-64", "System-32", "User")]
		[string]$Context = 'System-64',
		[Parameter(Mandatory = $false)]
		[string]$MSIPath,
		[Parameter(Mandatory = $false)]
		[string]$InstallLocation,
		[Parameter(Mandatory = $false)]
		[string]$IcoPath,
		[Parameter(Mandatory = $false)]
		[string]$UninstallString = 'Default'
	)
	
	Begin
	{
		## Get the name of this function and write header
		[string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
		Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -CmdletBoundParameters $PSBoundParameters -Header
	}
	Process
	{
		# Preset Initial Variables
		$aName = $appName
		$aVer = $appVersion
		$aVend = $appVendor
		
		# If MSIPath present, collect data from MSI
		if ($MSIPath)
		{
			$aName = (Get-MsiTableProperty -Path $MSIPath).ProductName
			$aVer = (Get-MsiTableProperty -Path $MSIPath).ProductVersion
			$aVend = (Get-MsiTableProperty -Path $MSIPath).Manufacturer
			$PCode = (Get-MsiTableProperty -Path $MSIPath).ProductCode
			if ($appUninstallCommandLine)
			{
				$UninstallString = "msiexec /x $PCode $appUninstallCommandLine /l*v 'C:\Program Files (x86)\Common Files\InstallLogs\MSI_UNINST_$aName-$aVer.log' REBOOT=R /qb!"
			}
			else
			{
				$UninstallString = "msiexec /x $PCode /l*v 'C:\Program Files (x86)\Common Files\InstallLogs\MSI_UNINST_$aName-$aVer.log' REBOOT=R /qb!"
			}
		}
		
		# set the registry entry name
		Switch ($Name)
		{
			'GUID' {
				if ($appMsiName -or $MSIPath)
				{
					[string]$Name = $PCode
				}
				else
				{
					[string]$Name = $appGUID
				}
			}
			'Default' { [string]$Name = $aName + " " + $aVer }
		}
		
		# set the registry path based on Context
		Switch ($Context)
		{
			'System-64' { [string]$regPath = ("HKLM:SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\$Name") }
			'System-32' { [string]$regPath = ("HKLM:SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\$Name") }
			'User' { [string]$regPath = ("Registry::HKEY_USERS\$((Get-LoggedOnUser).SID)\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\$Name") }
		}
		
		# Set Uninstall String if Default
		if (($UninstallString -match 'Default'))
		{
			$UninstallString = "$scriptPath\Install.exe /uninstall"
		}
		
		if ($action -eq 'Add')
		{
			# collect pacakge size
			[array]$pkgSize = $dirFiles | Get-ChildItem | Measure-Object -Sum Length | Select-Object @{ Name = "Size"; Expression = { $_.Sum / 1KB -as [int] } }
			
			# create table for registry entries
			$regInfo = @(
				[pscustomobject]@{ Name = 'DisplayName'; Value = "$aName"; Type = 'String' }
				[pscustomobject]@{ Name = 'DisplayVersion'; Value = "$aVer"; Type = 'String' }
				[pscustomobject]@{ Name = 'InstallDate'; Value = (Get-Date -Format yyyyMMdd); Type = 'String' }
				[pscustomobject]@{ Name = 'EstimatedSize'; Value = $pkgSize.Size; Type = 'DWord' }
				[pscustomobject]@{ Name = 'Language'; Value = "1033"; Type = 'DWord' }
				[pscustomobject]@{ Name = 'NoModify'; Value = "1"; Type = 'DWord' }
				[pscustomobject]@{ Name = 'NoRepair'; Value = "1"; Type = 'DWord' }
				[pscustomobject]@{ Name = 'Publisher'; Value = "$aVend"; Type = 'String' }
				[pscustomobject]@{ Name = 'Comments'; Value = "Federal Reserve Bank System -- EUS"; Type = 'String' }
				[pscustomobject]@{ Name = 'Contact'; Value = "Please contact your local Help Desk"; Type = 'String' }
				[pscustomobject]@{ Name = 'HelpLink'; Value = "Please contact your local Help Desk"; Type = 'String' }
				[pscustomobject]@{ Name = 'URLInfoAbout'; Value = "Please contact your local Help Desk"; Type = 'String' }
				[pscustomobject]@{ Name = 'URLUpdateInfo'; Value = "Please contact your local Help Desk"; Type = 'String' }
				[pscustomobject]@{ Name = 'Readme'; Value = "Please contact your local Help Desk"; Type = 'String' }
				[pscustomobject]@{ Name = 'UninstallString'; Value = "$UninstallString"; Type = 'String' }
			)
			
			# Creating Icon entry if entered
			if ($IcoPath)
			{
				$regInfo += @(
					[pscustomobject]@{ Name = 'DisplayIcon'; Value = "$IcoPath"; Type = 'String' }
				)
			}
			
			# Creating InstallLocation entry if entered
			if ($InstallLocation)
			{
				$regInfo += @(
					[pscustomobject]@{ Name = 'InstallLocation'; Value = "$InstallLocation"; Type = 'String' }
				)
			}
			
			# Create top-level registry key
			Write-Log -Message "Creating top-level registry entry" -LogType CMTrace -Source ${CmdletName}
			Set-RegistryKey -Key $regPath
			
			# Apply all registry entries
			ForEach ($entry in $regInfo)
			{
				Write-Log -Message ("Adding entry for " + $entry.Name) -LogType CMTrace -Source ${CmdletName}
				Set-RegistryKey -Key $regPath -Name $entry.Name -Value ($entry.Value) -Type $entry.Type
			}
			
			Write-Log -Message "Completed creating ARP Entry for $Name." -LogType CMTrace -Source ${CmdletName}
		}
		elseif ($action -eq 'Remove')
		{
			Write-Log -Message "Removing $regPath" -LogType CMTrace -Source ${CmdletName}
			Remove-RegistryKey -Key $regPath
			Write-Log -Message "Completed removal of ARP Entry $Name." -LogType CMTrace -Source ${CmdletName}
		}
		
	}
	End
	{
		Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -Footer
	}
}

#endregion

#region Function Copy-ContentToCache
Function Copy-ContentToCache
{
    <#
.SYNOPSIS
    Copies the $dirFiles content to a cache folder on the local machine and sets the $dirFiles directory to the cache path
.DESCRIPTION
    Copies the $dirFiles content to a cache folder on the local machine and sets the $dirFiles directory to the cache path
.PARAMETER Path
    The path to the software cache folder
.EXAMPLE
    Copy-ContentToCache -Path 'C:\Windows\Temp\PSAppDeployToolkit'
.NOTES
    This function is provided as a template to copy the $dirFiles content to a cache folder on the local machine and set the $dirFiles directory to the cache path.
    This can be used in the absence of an Endpoint Management solution that provides a managed cache for source files, e.g. Intune is lacking this functionality whereas ConfigMgr includes this functionality.
    Since this cache folder is effectively unmanaged, it is important to cleanup the cache in the uninstall section for the current version and potentially also in the pre-installation section for previous versions.
    This can be done using [Remove-File -Path "$configToolkitCachePath\$installName" -Recurse -ContinueOnError $true] or via the Remove-ContentFromCache function.

.LINK
    https://psappdeploytoolkit.com
#>
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $false, Position = 0, HelpMessage = 'The path to the software cache folder')]
		[ValidateNotNullorEmpty()]
		[String]$Path = "$configToolkitCachePath\$installName"
	)
	
	Begin
	{
		## Get the name of this function and write header
		[String]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
		Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -CmdletBoundParameters $PSBoundParameters -Header
	}
	Process
	{
		Try
		{
			## Create the cache folder if it does not exist
			If (-not (Test-Path -LiteralPath $Path -PathType 'Container'))
			{
				Try
				{
					Write-Log -Message "Creating cache folder [$Path]." -Source ${CmdletName}
					$null = New-Item -Path $Path -ItemType 'Directory' -ErrorAction 'Stop'
				}
				Catch
				{
					Write-Log -Message "Failed to create cache folder [$Path]. `r`n$(Resolve-Error)" -Severity 3 -Source ${CmdletName}
				}
			}
			Else
			{
				Write-Log -Message "Cache folder [$Path] already exists." -Source ${CmdletName}
			}
			
			## Copy the '.\Data' content to the cache folder
			Write-Log -Message "Copying [$dirFiles] content to cache folder [$Path]." -Source ${CmdletName}
			Copy-File -Path (Join-Path -Path $dirFiles -ChildPath '*') -Destination $Path -Recurse
			# Set the Files directory to the cache path
			Set-Variable -Name 'dirFiles' -Value $Path -Scope 'Script'
			#Set-Variable -Name 'dirSupportFiles' -Value "$Path\SupportFiles" -Scope 'Script'
		}
		Catch
		{
			Write-Log -Message "Failed to copy [$dirFiles] content to cache folder [$Path]. `r`n$(Resolve-Error)" -Severity 3 -Source ${CmdletName}
		}
	}
	End
	{
		Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -Footer
	}
}
#endregion

#region Function Remove-ContentFromCache
Function Remove-ContentFromCache
{
    <#
.SYNOPSIS
    Removes the $dirFiles content from the cache folder on the local machine and reverts the $dirFiles directory
.DESCRIPTION
    Removes the $dirFiles content from the cache folder on the local machine and reverts the $dirFiles directory
.PARAMETER Path
    The path to the software cache folder
.EXAMPLE
    Remove-ContentFromCache -Path 'C:\Windows\Temp\PSAppDeployToolkit'
.NOTES

.LINK
    https://psappdeploytoolkit.com
#>
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $false, Position = 0, HelpMessage = 'The path to the software cache folder')]
		[ValidateNotNullorEmpty()]
		[String]$Path = "$configToolkitCachePath\$installName"
	)
	
	Begin
	{
		## Get the name of this function and write header
		[String]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
		Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -CmdletBoundParameters $PSBoundParameters -Header
	}
	Process
	{
		Try
		{
			If (Test-Path -LiteralPath $Path -PathType 'Container')
			{
				Write-Log -Message "Removing cache folder [$Path]." -Source ${CmdletName}
				## Close the Installation Progress Dialog if running
				If ($global:PromptedInstall -eq 1) { Stop-Process -Name "EUSInstallProgress" -Force -ErrorAction SilentlyContinue }
				Remove-Folder -Path $Path -ErrorAction Stop
				[String]$dirFiles = Join-Path -Path $scriptParentPath -ChildPath 'Data'
			}
			Else
			{
				Write-Log -Message "Cache folder [$Path] does not exist." -Source ${CmdletName}
			}
		}
		Catch
		{
			Write-Log -Message "Failed to remove cache folder [$Path]. `r`n$(Resolve-Error)" -Severity 3 -Source ${CmdletName}
		}
	}
	End
	{
		Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -Footer
	}
}
#endregion

#region Function Copy-FileToUserProfiles
function Copy-FileToUserProfiles
{
    <#
.SYNOPSIS

Copy one or more items to a each user profile on the system.

.DESCRIPTION

Copy one or more items to a each user profile on the system.

.PARAMETER Path

The path of the file or folder to copy.

.PARAMETER Destination

The path of the destination folder to append to the root of the user profile.

.PARAMETER Recurse

Copy files in subdirectories.

.PARAMETER Flatten

Flattens the files into the root destination directory.

.PARAMETER ContinueOnError

Continue if an error is encountered. This will continue the deployment script, but will not continue copying files if an error is encountered. Default is: $true.

.PARAMETER ContinueFileCopyOnError

Continue copying files if an error is encountered. This will continue the deployment script and will warn about files that failed to be copied. Default is: $false.

.PARAMETER UseRobocopy

Use Robocopy to copy files rather than native PowerShell method. Robocopy overcomes the 260 character limit. Only applies if $Path is specified as a folder. Default is configured in the AppDeployToolkitConfig.xml file: $true

.PARAMETER RobocopyAdditionalParams

Additional parameters to pass to Robocopy. Default is: $null

.PARAMETER ExcludeNTAccount

Specify NT account names in Domain\Username format to exclude from the list of user profiles.

.PARAMETER ExcludeSystemProfiles

Exclude system profiles: SYSTEM, LOCAL SERVICE, NETWORK SERVICE. Default is: $true.

.PARAMETER ExcludeServiceProfiles

Exclude service profiles where NTAccount begins with NT SERVICE. Default is: $true.

.PARAMETER ExcludeDefaultUser

Exclude the Default User. Default is: $false.

.INPUTS

You can pipe in string values for $Path.

.OUTPUTS

None

This function does not generate any output.

.EXAMPLE

Copy-FileToUserProfiles -Path "$dirSupportFiles\config.txt" -Destination "AppData\Roaming\MyApp"

Copy a single file to C:\Users\<UserName>\AppData\Roaming\MyApp for each user.

.EXAMPLE

Copy-FileToUserProfiles -Path "$dirSupportFiles\config.txt","$dirSupportFiles\config2.txt" -Destination "AppData\Roaming\MyApp"

Copy two files to C:\Users\<UserName>\AppData\Roaming\MyApp for each user.

.EXAMPLE

Copy-FileToUserProfiles -Path "$dirFiles\MyApp" -Destination "AppData\Local" -Recurse

Copy an entire folder to C:\Users\<UserName>\AppData\Local for each user.

.EXAMPLE

Copy-FileToUserProfiles -Path "$dirFiles\.appConfigFolder" -Recurse

Copy an entire folder to C:\Users\<UserName> for each user.

.NOTES

.LINK

https://psappdeploytoolkit.com
#>
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $true, Position = 1, ValueFromPipeline = $true)]
		[String[]]$Path,
		[Parameter(Mandatory = $false, Position = 2)]
		[String]$Destination,
		[Parameter(Mandatory = $false)]
		[Switch]$Recurse = $false,
		[Parameter(Mandatory = $false)]
		[Switch]$Flatten,
		[Parameter(Mandatory = $false)]
		[ValidateNotNullOrEmpty()]
		[Boolean]$UseRobocopy = $configToolkitUseRobocopy,
		[Parameter(Mandatory = $false)]
		[ValidateNotNullOrEmpty()]
		[String]$RobocopyAdditionalParams = $null,
		[Parameter(Mandatory = $false)]
		[ValidateNotNullOrEmpty()]
		[String[]]$ExcludeNTAccount,
		[Parameter(Mandatory = $false)]
		[ValidateNotNullOrEmpty()]
		[Boolean]$ExcludeSystemProfiles = $true,
		[Parameter(Mandatory = $false)]
		[ValidateNotNullOrEmpty()]
		[Boolean]$ExcludeServiceProfiles = $true,
		[Parameter(Mandatory = $false)]
		[ValidateNotNullOrEmpty()]
		[Switch]$ExcludeDefaultUser = $false,
		[Parameter(Mandatory = $false)]
		[ValidateNotNullOrEmpty()]
		[Boolean]$ContinueOnError = $true,
		[Parameter(Mandatory = $false)]
		[ValidateNotNullOrEmpty()]
		[Boolean]$ContinueFileCopyOnError = $false
	)
	
	Begin
	{
		## Get the name of this function and write header
		[String]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
		Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -CmdletBoundParameters $PSBoundParameters -Header
	}
	Process
	{
		[Hashtable]$CopyFileSplat = @{
			Path				    = $Path
			Recurse				    = $Recurse
			Flatten				    = $Flatten
			ContinueOnError		    = $ContinueOnError
			ContinueFileCopyOnError = $ContinueFileCopyOnError
			UseRobocopy			    = $UseRobocopy
		}
		if ($RobocopyAdditionalParams)
		{
			$CopyFileSplat.RobocopyAdditionalParams = $RobocopyAdditionalParams
		}
		
		[Hashtable]$GetUserProfileSplat = @{
			ExcludeSystemProfiles  = $ExcludeSystemProfiles
			ExcludeServiceProfiles = $ExcludeServiceProfiles
			ExcludeDefaultUser	   = $ExcludeDefaultUser
		}
		if ($ExcludeNTAccount)
		{
			$GetUserProfileSplat.ExcludeNTAccount = $ExcludeNTAccount
		}
		
		foreach ($UserProfilePath in (Get-UserProfiles @GetUserProfileSplat).ProfilePath)
		{
			$CopyFileSplat.Destination = Join-Path $UserProfilePath $Destination
			Write-Log -Message "Copying path [$Path] to $($CopyFileSplat.Destination):" -Source ${CmdletName}
			Copy-File @CopyFileSplat
		}
	}
	End
	{
		Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -Footer
	}
}
#endregion

#region Function Remove-FileFromUserProfiles
Function Remove-FileFromUserProfiles
{
    <#
.SYNOPSIS

Removes one or more items from each user profile on the system.

.DESCRIPTION

Removes one or more items from each user profile on the system.

.PARAMETER Path

Specifies the path to append to the root of the user profile to be resolved. The value of Path will accept wildcards. Will accept an array of values.

.PARAMETER LiteralPath

Specifies the path to append to the root of the user profile to be resolved. The value of LiteralPath is used exactly as it is typed; no characters are interpreted as wildcards. Will accept an array of values.

.PARAMETER Recurse

Deletes the files in the specified location(s) and in all child items of the location(s).

.PARAMETER ExcludeNTAccount

Specify NT account names in Domain\Username format to exclude from the list of user profiles.

.PARAMETER ExcludeSystemProfiles

Exclude system profiles: SYSTEM, LOCAL SERVICE, NETWORK SERVICE. Default is: $true.

.PARAMETER ExcludeServiceProfiles

Exclude service profiles where NTAccount begins with NT SERVICE. Default is: $true.

.PARAMETER ExcludeDefaultUser

Exclude the Default User. Default is: $false.

.PARAMETER ContinueOnError

Continue if an error is encountered. Default is: $true.

.INPUTS

None

You cannot pipe objects to this function.

.OUTPUTS

None

This function does not generate any output.

.EXAMPLE

Remove-FileFromUserProfiles -Path "AppData\Roaming\MyApp\config.txt"

.EXAMPLE

Remove-FileFromUserProfiles -Path "AppData\Local\MyApp" -Recurse

.NOTES

.LINK

https://psappdeploytoolkit.com
#>
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $true, Position = 0, ParameterSetName = 'Path')]
		[ValidateNotNullorEmpty()]
		[String[]]$Path,
		[Parameter(Mandatory = $true, Position = 0, ParameterSetName = 'LiteralPath')]
		[ValidateNotNullorEmpty()]
		[String[]]$LiteralPath,
		[Parameter(Mandatory = $false)]
		[Switch]$Recurse = $false,
		[Parameter(Mandatory = $false)]
		[ValidateNotNullOrEmpty()]
		[String[]]$ExcludeNTAccount,
		[Parameter(Mandatory = $false)]
		[ValidateNotNullOrEmpty()]
		[Boolean]$ExcludeSystemProfiles = $true,
		[Parameter(Mandatory = $false)]
		[ValidateNotNullOrEmpty()]
		[Boolean]$ExcludeServiceProfiles = $true,
		[Parameter(Mandatory = $false)]
		[ValidateNotNullOrEmpty()]
		[Switch]$ExcludeDefaultUser = $false,
		[Parameter(Mandatory = $false)]
		[ValidateNotNullOrEmpty()]
		[Boolean]$ContinueOnError = $true
	)
	
	Begin
	{
		## Get the name of this function and write header
		[String]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
		Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -CmdletBoundParameters $PSBoundParameters -Header
	}
	Process
	{
		[Hashtable]$RemoveFileSplat = @{
			Recurse		    = $Recurse
			ContinueOnError = $ContinueOnError
		}
		
		[Hashtable]$GetUserProfileSplat = @{
			ExcludeSystemProfiles  = $ExcludeSystemProfiles
			ExcludeServiceProfiles = $ExcludeServiceProfiles
			ExcludeDefaultUser	   = $ExcludeDefaultUser
		}
		if ($ExcludeNTAccount)
		{
			$GetUserProfileSplat.ExcludeNTAccount = $ExcludeNTAccount
		}
		
		ForEach ($UserProfilePath in (Get-UserProfiles @GetUserProfileSplat).ProfilePath)
		{
			If ($PSCmdlet.ParameterSetName -eq 'Path')
			{
				$RemoveFileSplat.Path = $Path | ForEach-Object { Join-Path $UserProfilePath $_ }
				Write-Log -Message "Removing path [$Path] from $UserProfilePath`:" -Source ${CmdletName}
			}
			ElseIf ($PSCmdlet.ParameterSetName -eq 'LiteralPath')
			{
				$RemoveFileSplat.LiteralPath = $LiteralPath | ForEach-Object { Join-Path $UserProfilePath $_ }
				Write-Log -Message "Removing literal path [$LiteralPath] from $UserProfilePath`:" -Source ${CmdletName}
			}
			Remove-File @RemoveFileSplat
		}
	}
	End
	{
		Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -Footer
	}
}
#endregion

#region Function Remove-InvalidFileNameChars
Function Remove-InvalidFileNameChars
{
    <#
.SYNOPSIS

Remove invalid characters from the supplied string.

.DESCRIPTION

Remove invalid characters from the supplied string and returns a valid filename as a string.

.PARAMETER Name

Text to remove invalid filename characters from.

.INPUTS

System.String

A string containing invalid filename characters.

.OUTPUTS

System.String

Returns the input string with the invalid characters removed.

.EXAMPLE

Remove-InvalidFileNameChars -Name "Filename/\1"

.NOTES

This functions always returns a string however it can be empty if the name only contains invalid characters.
Do no use this command for an entire path as '\' is not a valid filename character.

.LINK

https://psappdeploytoolkit.com
#>
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
		[AllowEmptyString()]
		[String]$Name
	)
	
	Begin
	{
		## Get the name of this function and write header
		[String]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
		Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -CmdletBoundParameters $PSBoundParameters -Header
	}
	Process
	{
		Try
		{
			Write-Output -InputObject (([Char[]]$Name | Where-Object { $invalidFileNameChars -notcontains $_ }) -join '')
		}
		Catch
		{
			Write-Log -Message "Failed to remove invalid characters from the supplied filename. `r`n$(Resolve-Error)" -Severity 3 -Source ${CmdletName}
		}
	}
	End
	{
		Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -Footer
	}
}
#endregion

#region Function Get-ADUserInfo
function Get-ADUserInfo
{
<#
.SYNOPSIS

Retrieves User account information from Active Directory.

.DESCRIPTION

Retrieves User account information from Active Directory.
Attributes retrieved are as follows:
    -ID
    -Name
    -Email
    -Title
    -District
    -Department
    -Groups
    -HomeFolder

.PARAMETER UserID

Specifies the account ID to search.

.PARAMETER Silent

Disables logging.

.INPUTS

None. You cannot pipe objects.

.OUTPUTS

PS Custom Object. Get-ADUserInfo returns an array of information listed in Description.

.EXAMPLE

PS> Get-ADUserInfo -UserID A1AAA01
ID         : A1AAA01
Name       : John Smith
Email      : John.Smith@dist.frb.org
Title      : Software Packager
District   : FRB District
Department : IT
Groups     : {TEST Group 1}
HomeFolder : \\rb.win.frb.org\A1\Home\A-C\A1AAA01
#>
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $true, Position = 1)]
		[ValidateNotNullorEmpty()]
		[String]$UserID,
		[Parameter(Mandatory = $false, Position = 2)]
		[Switch]$Silent
	)
	Begin
	{
		## Get the name of this function and write header
		[String]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
		Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -CmdletBoundParameters $PSBoundParameters -Header
	}
	Process
	{
		## Search AD
		$objSearcher = [adsisearcher]"(&(objectCategory=person)(objectClass=user)(SAMAccountName=$UserID))"
		## Validate there's a match found
		if ($null -ne $objSearcher.FindOne())
		{
			## Pull respective attributes
			$userInfo = ($objSearcher.FindOne().Properties) | Select-Object `
				@{ Name = 'ID'; Expression = { $PSItem.name } },
				@{ Name = 'Name'; Expression = { [string]($PSItem.givenname + $PSItem.sn) } },
				@{ Name = 'Email'; Expression = { $PSItem.mail } },
				@{ Name = 'Title'; Expression = { $PSItem.title } },
				@{ Name = 'District'; Expression = { $PSItem.company } },
				@{ Name = 'Department'; Expression = { $PSItem.department } },
				@{ Name = 'Groups'; Expression = { $PSItem.memberof | ForEach-Object { ($PSItem -replace '^CN\=|\,OU\=.+', '') } } },
				@{ Name = 'HomeFolder'; Expression = { $PSItem.homedirectory } },
				@{ Name = 'DistinguishedName'; Expression = { $PSItem.distinguishedname } }
				#@{Name='';Expression={}}
		}
		else
		{
			if (-not $Silent) { Write-Log -Message "No account found matching [$userID]." -Severity 3 -Source ${CmdletName} -LogType CMTrace }
		}
	}
	End
	{
		if (-not $Silent) { Write-Log -Message "Account found matching [$userID]." -Source ${CmdletName} -LogType CMTrace }
		Write-Output -InputObject ($userInfo)
		Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -Footer
	}
}
#endregion

#region Function Get-ADGroupInfo
function Get-ADGroupInfo
{
<#
.SYNOPSIS

Retrieves group account information from Active Directory.

.DESCRIPTION

Retrieves group account information from Active Directory.
Attributes retrieved are as follows:
    -Name
    -Description
    -Owner
    -Members
    -MemberOf

.PARAMETER Group

Specifies the group name to search.

.INPUTS

None. You cannot pipe objects.

.OUTPUTS

PS Custom Object. Get-ADGroupInfo returns an array of information listed in Description.

.EXAMPLE

PS> Get-ADGroupInfo -Name 'Test-Group'
Name        : Test-Group
Description : Test AD Group
Owner       : A1AAA01 - John Smith
Members     : {A1AAA01, A1AAA02, A1AAA03, A1AAA04…}
MemberOf    : {Another-Test-Group}
	
.NOTES
	
You cannot search groups that exceed 1000 members at this time.
#>
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $true, Position = 1)]
		[Alias('Name')]
		[ValidateNotNullorEmpty()]
		[String]$Group
	)
	Begin
	{
		## Get the name of this function and write header
		[String]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
		Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -CmdletBoundParameters $PSBoundParameters -Header
	}
	Process
	{
		## Search AD
		$objSearcher = [adsisearcher]"(&(objectCategory=group)(objectClass=group)(SAMAccountName=$Group))"
		## Validate there's a match found
		if ($null -ne $objSearcher.FindOne())
		{
			## Pull respective attributes
			$groupInfo = ($objSearcher.FindOne().Properties) | Select-Object `
				@{ Name = 'Name'; Expression = { $PSItem.cn } },
				@{ Name = 'Description'; Expression = { $PSItem.description } },
				@{ Name = 'Owner'; Expression = { ((Get-ADUserInfo -UserID $($PSItem.managedby -replace '^CN\=|\,OU\=.+', '') -Silent) | Select-Object @{ n = 'Info'; e = { [string]($PSItem.ID + " - " + $PSItem.Name) } }).Info } },
				@{ Name = 'Members'; Expression = { $PSItem.member | ForEach-Object { ($PSItem -replace '^CN\=|\,OU\=.+', '') } } },
				@{ Name = 'MemberOf'; Expression = { $PSItem.memberof | ForEach-Object { ($PSItem -replace '^CN\=|\,OU\=.+', '') } } }
				#@{Name='';Expression={}}
		}
		else
		{
			Write-Log -Message "No group found matching [$Group]." -Severity 3 -Source ${CmdletName} -LogType CMTrace
		}
	}
	End
	{
		if ($groupInfo)
		{
			Write-Log -Message "Account found matching [$Group]." -Source ${CmdletName} -LogType CMTrace
			Write-Output -InputObject ($groupInfo)
		}
		Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -Footer
	}
}
#endregion

#region Function Get-SystemInformation
function Get-SystemInformation
{
<#
.SYNOPSIS

Retrieves User and Device information.

.DESCRIPTION

Retrieves User and Device information from the local system.

.PARAMETER Silent

Disables logging.

.INPUTS

None. You cannot pipe objects.

.OUTPUTS

Hashtable. Get-SystemInformation returns an array of information.

.EXAMPLE

PS> Get-SystemInformation
Name                           Value                                                                                                                                                                                                                             
----                           -----                                                                                                                                                                                                                             
USERNAME                       A1AAA00
USERDNSDOMAIN                  ABC.COM
USERPROFILE                    C:\Users\A1AAA00
LastRebootTime                 6/28/2024 7:00:00 AM
PendingReboot                  True
FreeDiskSpace                  120.50 GB

.NOTES
The returned user-based values will vary. Not all users share the exact same environment variables.
The following entries will always be made:
    -LastRebootTime
    -PendingReboot
    -FreeDiskSpace
#>
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $false, Position = 1)]
		[Switch]$Silent
	)
	Begin
	{
		## Get the name of this function and write header
		[String]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
		Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -CmdletBoundParameters $PSBoundParameters -Header
	}
	Process
	{
		# Create initial hashtable
		[hashtable]$infoHash = @{ }
		
		#Check for a logged in user
		[array]$usrInfo = [PSADT.QueryUser]::GetUserSessionInfo("$env:ComputerName")
		
		# Get info on logged in user
		if ($usrInfo)
		{
			# Add some initial user data to the hash
			$infoHash.Add('SID', $usrInfo.SID)
			# Collect user environment variables
			'Environment', 'Volatile Environment' | ForEach-Object {
				$regProperties = Get-ItemProperty -Path "Registry::HKEY_USERS\$($usrInfo.SID)\$PSItem"
				$regProperties.psobject.properties.Name | ForEach-Object {
					if ($PSItem -notmatch 'PSPath|PSParentPath|PSChildName|PSProvider')
					{
						$infoHash.Add($PSItem, $regProperties.$PSItem)
					}
				}
			}
		}
		
		# Gather reboot info
		$rebootInfo = Get-PendingReboot -Silent
		$pendingBoots = $false
		# Determine if a reboot is needed
		$rebootInfo | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | ForEach-Object {
			if ($rebootInfo.$PSItem -eq 'True')
			{
				$pendingBoots = $true
			}
		}
		
		# Add reboot info to hash
		$infoHash.Add('LastRebootTime', $rebootInfo.LastBootUpTime)
		$infoHash.Add('PendingReboot', $pendingBoots)
		
		# Add free disk space to hash
		$infoHash.Add('FreeDiskSpace', "$([math]::Round(((Get-CimInstance -Class 'Win32_LogicalDisk' -Filter "DeviceID='$env:SystemDrive'" -ErrorAction 'Stop').FreeSpace / 1024MB), 2)) GB")
		
		if (-not $Silent)
		{
			# Compile logging info
			$logInfo = New-Object -TypeName PSCustomObject
			if ($usrInfo)
			{
				$logInfo | Add-Member -NotePropertyName 'Logged In User' -NotePropertyValue $infoHash.UserName
				$logInfo | Add-Member -NotePropertyName 'SID' -NotePropertyValue $infoHash.SID
				$logInfo | Add-Member -NotePropertyName 'Profile Path' -NotePropertyValue $infoHash.USERPROFILE
				$logInfo | Add-Member -NotePropertyName 'Home Drive' -NotePropertyValue $infoHash.HOMEDRIVE
				$logInfo | Add-Member -NotePropertyName 'Home Share' -NotePropertyValue $infoHash.HOMESHARE
				$logInfo | Add-Member -NotePropertyName 'Domain' -NotePropertyValue $infoHash.USERDNSDOMAIN
			}
			else
			{
				$logInfo | Add-Member -NotePropertyName 'Logged In User' -NotePropertyValue 'N/A'
			}
			$logInfo | Add-Member -NotePropertyName 'Free Disk Space' -NotePropertyValue $infoHash.FreeDiskSpace
			$logInfo | Add-Member -NotePropertyName 'Last Bootup Time' -NotePropertyValue $infoHash.LastRebootTime
			$logInfo | Add-Member -NotePropertyName 'Pending Reboot' -NotePropertyValue $infoHash.PendingReboot
			
			# Write log info
			Foreach ($log in $logInfo.psobject.properties.Name)
			{
				Write-Log -Message "$log`: $($logInfo.$log)" -Source ${CmdletName} -LogType CMTrace
			}
		}
	}
	End
	{
		Write-Output -InputObject ($infoHash)
		Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -Footer
	}
}

#endregion Function Get-SystemInformation

#region Function Set-PsadtAppLock 
function Set-PsadtAppLock 
{	
<#
.SYNOPSIS

Uses mutex to ensure only one instance of the Install.exe can run at a time

.DESCRIPTION

Queues multiple running Install.exe so that they do not all run at the same time.

.PARAMETER Date

Date is defaulted to the current date but can be specified.

.INPUTS

None.

.OUTPUTS

None

.EXAMPLE

This function is normally silently run internally.

.NOTES

There is no uer interaction.

#>
	[CmdletBinding()]
	Param (
		[Parameter(ValueFromPipeline = $true)]
        [DateTime]$Date = (Get-Date)
	)
	Begin{
		## Get the name of this function and write header
		[String]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
		Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -CmdletBoundParameters $PSBoundParameters -Header
	}
	Process{
		while ((($Date) -lt $maxDuration) -and (!($mtx.WaitOne(1000))))
		{
			Write-Log -Message "Mutex busy, waiting 30 seconds..."  -Source ${CmdletName}
			Start-Sleep -Seconds 30
		}
		if (!($mtx.WaitOne(1000)))
		{
			Write-Log -Message "Another Installer is currently running. Exiting with return code of 1"  -Source ${CmdletName}
			$mtx.Dispose()
			Exit-Script -ExitCode 1
		}
	}
	End{
		Write-Output -InputObject ($infoHash)
		Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -Footer
	}

}
#endregion Function Set-PsadtAppLock 

#region Function Get-DialogTimingConfig
function Get-DialogTimingConfig
{
<#
.SYNOPSIS

Reads per-package dialog timer/delay-option overrides.

.DESCRIPTION

Looks for Data\dialog-config.json (per-package, optional). If present,
returns its values merged over the built-in defaults below; if absent or
unreadable, returns the defaults unchanged. This lets a package override
just the specific timer/delay values technicians have identified as real
pain points, without touching any dialog's layout, wording, or branding.

Supported keys (all optional - only override what you need):
  CloseOpenAppsTimeoutMinutes      (default 5)   - CloseOpenApps.psf countdown
  InstallInformationTimeoutMinutes (default 10)  - InstallInformation.psf countdown
  InstallReminderTimeoutMinutes    (default 10)  - InstallReminder.psf countdown
  DelayOptionsNormalMinutes        (default [30, 60, 120])  - 3 delay choices, normal install
  DelayOptionsForceRebootMinutes   (default [60, 120, 180]) - 3 delay choices, forced reboot
  LastCallMinutes                  (default 10)  - TimeDelayLastCall.psf single option

.OUTPUTS

Hashtable with the keys above, always fully populated (defaults filled in
for anything the JSON file didn't specify).

.EXAMPLE

$dialogConfig = Get-DialogTimingConfig
$script:EndTimeOpenProcess = (Get-Date).AddMinutes($dialogConfig.CloseOpenAppsTimeoutMinutes)
#>

	$defaults = @{
		CloseOpenAppsTimeoutMinutes = 5
		InstallInformationTimeoutMinutes = 10
		InstallReminderTimeoutMinutes = 10
		DelayOptionsNormalMinutes = @(30, 60, 120)
		DelayOptionsForceRebootMinutes = @(60, 120, 180)
		LastCallMinutes = 10
	}

	try
	{
		$configPath = Join-Path -Path $dirFiles -ChildPath 'dialog-config.json'
		if (-not (Test-Path -LiteralPath $configPath -PathType Leaf))
		{
			return $defaults
		}

		$overrides = Get-Content -Path $configPath -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
		foreach ($key in @($defaults.Keys))
		{
			if ($overrides.PSObject.Properties[$key] -and $null -ne $overrides.$key)
			{
				$defaults[$key] = $overrides.$key
			}
		}
	}
	catch
	{
		# Malformed or unreadable config - fall back to defaults rather than block the install
	}

	return $defaults
}
#endregion Function Get-DialogTimingConfig

#region Function Get-QuarterInfo
function Get-QuarterInfo
{
<#
.SYNOPSIS

Gets the Date and Quarter of the year

.DESCRIPTION

Returns the Date, Year, and Quarter of the year information

.PARAMETER Date

Date is defaulted to the current date but can be specified.

.INPUTS

None.

.OUTPUTS

None

.EXAMPLE

$quarter = Get-QuarterInfo
$quarter.Date
$quarter.Quarter
$quarter.QuarterName
$quarter.StartDate
$quarter.EndDate
$quarter.DaysInQuarter
$quarter.DaysRemaningInQuarter

.NOTES

There is no uer interaction.

#>
    [CmdletBinding()]
    param (
		[Parameter(ValueFromPipeline = $true)]
        [DateTime]$Date = (Get-Date)
	)
	Begin{
		## Get the name of this function and write header
		[String]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
		Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -CmdletBoundParameters $PSBoundParameters -Header
	}
    Process {
        $quarter = [Math]::Ceiling($Date.Month / 3)
        $startMonth = (($quarter - 1) * 3) + 1
        $endMonth = $quarter * 3

        $startDate = Get-Date -Year $Date.Year -Month $startMonth -Day 1
        $endDate = (Get-Date -Year $Date.Year -Month $endMonth -Day 1).AddMonths(1).AddDays(-1)

        [PSCustomObject]@{
            Date = $Date
            Quarter = $quarter
            QuarterName = "Q$quarter $($Date.Year)"
            StartDate = $startDate
            EndDate = $endDate
            DaysInQuarter = ($endDate - $startDate).Days + 1
            DaysRemainingInQuarter = ($endDate - $Date).Days
        }
    }
	End{
		Write-Output -InputObject ($infoHash)
		Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -Footer
	}
}
#endregion Function Get-QuarterInfo

#region Function Start-TryParse
function Start-TryParse
{
<#
.SYNOPSIS
    Verifies that a version string is valid and can be parsed as a System.Version object.

.DESCRIPTION
    This function attempts to parse a version string using System.Version.TryParse to validate
    that the provided string conforms to the expected version format (e.g., "1.0.0.0").
    Returns $true if the version string is valid, $false otherwise.

.PARAMETER VersionString
    The version string to validate. This should be in a format compatible with System.Version
    (e.g., "1.0", "1.0.0", "1.0.0.0").

.EXAMPLE
    Start-TryParse -VersionString "1.2.3.4"
    Returns $true as the version string is valid.

.EXAMPLE
    Start-TryParse -VersionString "invalid.version"
    Returns $false as the version string is not valid.

.INPUTS
    System.String
    The version string to validate.

.OUTPUTS
    System.Boolean
    Returns $true if the version string is valid, $false otherwise.

.NOTES
    Author: DevOps Specialist
    Version: 1.0
    This function is useful for validating version strings from JSON or other configuration sources
    before attempting to use them in version comparisons or installations.
#>
	param (
		[Parameter(Mandatory = $true)]
		[string]$VersionString
	)
	# TryParse $VersionString
	$version = $null
	$pass = [System.Version]::TryParse($VersionString, [ref]$version)
	if ($pass)
	{
		return $true
	}
	else
	{
		return $false
	}
}
#endregion Function Start-TryParse