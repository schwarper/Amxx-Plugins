#pragma semicolon 1

#include <amxmodx>

enum _:ArrayData {
	SwearName[MAX_FMT_LENGTH],
	SwearLen
};

new Array:g_aSwearsList;
new g_iAdmin_Immunity_Flag;
new g_iAdmin_Send_Message_Flag;

public plugin_precache() {
	register_plugin("Swear Filter", "0.0.4", "PurposeLess");

	new szFileName[40];
	get_localinfo("amxx_configsdir", szFileName, charsmax(szFileName));
	add(szFileName, charsmax(szFileName), "/swear_filter.ini");

	if(!file_exists(szFileName)) {
		log_amx("%s file does not exist. Swear Filter is down.", szFileName);
		pause("d");
		return;
	}

	g_aSwearsList = ArrayCreate(ArrayData);

	new iFile = fopen(szFileName, "r");

	if(iFile) {
		new szBuffer[MAX_FMT_LENGTH], szData[ArrayData], szLeft[64], szRight[64], iCount;

		while(!feof(iFile)) {
			fgets(iFile, szBuffer, charsmax(szBuffer));
			trim(szBuffer);

			if(szBuffer[0] == EOS || szBuffer[0] == ';') {
				continue;
			}

			if(szBuffer[0] == '-' && szBuffer[1] == '>') {
				strtok2(szBuffer, szLeft, charsmax(szLeft), szRight, charsmax(szRight), '=', TRIM_FULL);
				remove_quotes(szRight);

				switch(szLeft[15]) {
					case 'i': {
						if(szRight[0] != EOS) {
							g_iAdmin_Immunity_Flag = read_flags(szRight);
						}
					}
					case 's': {
						if(szRight[0] != EOS) {
							g_iAdmin_Send_Message_Flag = read_flags(szRight);
						}
					}
				}
				continue;
			}

			szData[SwearName] = szBuffer;
			szData[SwearLen] = strlen(szBuffer);
			iCount++;

			ArrayPushArray(g_aSwearsList, szData);
		}
		fclose(iFile);

		if(iCount > 0) {
			register_clcmd("say", "@clcmd_say");
			register_clcmd("say_team", "@clcmd_sayteam");
		}
	}
}

@clcmd_say(const pPlayer) {
	return SwearFilter(pPlayer, false);
}

@clcmd_sayteam(const pPlayer) {
	return SwearFilter(pPlayer, true);
}

bool:SwearFilter(const pPlayer, const blSayTeam) {
	if(g_iAdmin_Immunity_Flag && get_user_flags(pPlayer) & g_iAdmin_Immunity_Flag) {
		return false;
	}

	server_print("WTF");

	new szArg[MAX_FMT_LENGTH];
	read_args(szArg, charsmax(szArg));

	new szData[ArrayData], bool:blFound, iCount, iContaini;

	new iSize = ArraySize(g_aSwearsList);
	while(iCount < iSize) {
		ArrayGetArray(g_aSwearsList, iCount, szData);

		if((iContaini = containi(szArg, szData[SwearName])) != -1) {
			while(szData[SwearLen]--) {
				szArg[iContaini++] = '*';
			}
			blFound = true;
			continue;
		}
		iCount++;
	}

	if(blFound) {
		console_cmd(pPlayer, "%s %s", blSayTeam ? "say_team" : "say", szArg);

		if(g_iAdmin_Send_Message_Flag) {
			read_args(szArg, charsmax(szArg));
			remove_quotes(szArg);

			for(new id = 1; id <= MaxClients; id++) {
				if(is_user_connected(id) && get_user_flags(id) & g_iAdmin_Send_Message_Flag) {
					client_print_color(id, print_team_grey, "^4[!] ^3%n: %s", pPlayer, szArg);
				}
			}
		}
		return true;
	}
	return false;
}
