/*
 * This is a program to test the automatic clicking behaviour of hidsim-plugin.
 * A Win32-API dialog is displayed infinitely until the "Yes"-Button is clicked.
 *
 * Compile it with:
 * 		 C:\MinGW\bin\gcc.exe -o check_button_click.exe check_buttton_click.c
 */

#include <windows.h>
#include <stdio.h>

int WINAPI WinMain(HINSTANCE hInstance, HINSTANCE hPrevInstance, PSTR szCmdLine,
    int nCmdShow)
{
	int msgBoxID = IDNO;
	printf("[*] Displaying a dialog\n");

	while(msgBoxID != IDYES)
	 msgBoxID = MessageBox(
	        NULL,
	        "If you are alive, please click a button.",
	        "Are you alive?",
	        MB_ICONEXCLAMATION | MB_YESNO
	    );

	printf("[*] \"Yes\"-button was clicked\nExiting...");

	return 0;
}
