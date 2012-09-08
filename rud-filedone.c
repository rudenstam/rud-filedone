#include <ctype.h>
#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>
#include <wait.h>


#define PROCESS_MKV 1
#define PROCESS_RAR 1
#define ZIPSCRIPT "/bin/zipscript-c"
#define GL_LOG "/ftp-data/logs/glftpd.log"
#define LOG_FILE "/ftp-data/logs/rud-filedone.log"

int writeLog(const char *filename, const char *msg) {
	FILE *fp;

	fp = fopen(filename, "a");

	if (!fp)
		goto error;
	if (fwrite(msg, strlen(msg), 1, fp) != 1);
		goto close;
	if (fclose(fp) != 0)
		goto error;
	return 0;
close:
	fclose(fp);
error:
	return errno;
}

int firstRar(const char *filename) {
	int firstRar = 0;
	const char *tmp;

	tmp = filename+strlen(filename)-5;


	int i;
	for (i = 0; tmp > filename; i++) {
		if (!isdigit(tmp[0])) {
			if (i == 0)
				firstRar = 1;
			break;
		}
		tmp--;
	}

	if (!firstRar) {
		char digits[16];
		char part[5];
		int value;

		memset(digits, 0, sizeof(digits));
		strncpy(digits, tmp+1, filename+strlen(filename)-5-tmp);
		value = atoi(digits);

		memset(part, 0, sizeof(part));
		strncpy(part, tmp-3, 4);

		if ((value == 1 && !strncmp(part, "part", 4)) || strncmp(part, "part", 4)) {
			firstRar = 1;
		}
	}


	return firstRar;
}

int main(int argc, char *argv[]) {
	char *filename = argv[1];
	char *path = argv[2];
	time_t t;
	char timeStr[128];
	char *ext = "";
	char *newstring;
	char completeString[4096];

	if (fork() == 0) {
		char *new_argv[argc+1];

		memcpy(new_argv, argv, sizeof(char *) * (argc+1));
		new_argv[0] = ZIPSCRIPT;
		execv(ZIPSCRIPT, new_argv);
		exit(127);
	}

	t = time(NULL);
	strftime(timeStr, sizeof(timeStr), "%a %b %e %T %Y", localtime(&t));

	char *tmp = strdup(filename);
	while (1) {
		newstring = strsep(&tmp, ".");
		if (newstring)
			ext = newstring;
		else
			break;
	}

	if (!strcmp(ext, "mkv")) {
#if PROCESS_MKV == 1
		snprintf(completeString, sizeof(completeString), "%s MKV_DONE: %s %s\n", timeStr, path, filename);
		writeLog(GL_LOG, completeString);
		writeLog(LOG_FILE, completeString);
#endif
	} else if (!strcmp(ext, "rar")) {
#if PROCESS_RAR == 1
		if (firstRar(filename)) {
			snprintf(completeString, sizeof(completeString), "%s FIRST_RAR: %s %s\n", timeStr, path, filename);
			writeLog(GL_LOG, completeString);
			writeLog(LOG_FILE, completeString);
		}
#endif
	}

	wait(NULL);

	exit(0);
}