/*
 * This is a program to test, whether any cursor movement occures.
 * It is used to test the random mouse movement of the hidsim-plugin.
 *
 * Compile it with:
 * 		 C:\MinGW\bin\gcc.exe -o check_mouse_movement.exe check_mouse_movement.c
 */
#include <windows.h>
#include <stdio.h>
#include <time.h>

#define INTERVAL 1000

/* Compares mouse coords at t0 with coords at t1 */
int check_mouse_movement() {
	POINT pt1, pt2;
	GetCursorPos(&pt1);
	Sleep(INTERVAL); /* Sleep time */
	GetCursorPos(&pt2);
	if ((pt1.x != pt2.x) && (pt1.y != pt2.y)) {
		/* Mouse moved */
		printf("[+] Mouse displacement by %l px in X- and %l px in Y-axis detected \n",
				pt1.x - pt2.x, pt1.y - pt2.y);
		return TRUE;
	}
	else {
		/* No mouse movement detected */
		printf("[+] No mouse movement occured in the last %d ms\n", INTERVAL);
		return FALSE;
	}
}

int WINAPI WinMain(HINSTANCE hInstance, HINSTANCE hPrevInstance, PSTR szCmdLine,
    int nCmdShow)
{
	printf("[*] Checking for mouse activity...\n");

    /* Loops until the mouse moved */
    while(!check_mouse_movement())
    {
        Sleep(500);
    }
    printf("[*] Mouse activity check succeeded! Exiting...\n");

	return 0;
}
