#pragma semicolon 1

#include <amxmodx>
#include <reapi>

public plugin_precache() {
	register_plugin("Set MapName", AMXX_VERSION_STR, "Schwarper");

	new szFileName[39];
	get_localinfo("amxx_configsdir", szFileName, charsmax(szFileName));
	add(szFileName, charsmax(szFileName), "/set_mapname.ini");

	new iFile = fopen(szFileName, "a+");

	if(iFile) {
		new szBuffer[MAX_FMT_LENGTH], szCurrentMap[32], szLeft[32], szRight[32], bool:blFound;
		get_mapname(szCurrentMap, charsmax(szCurrentMap));

		while(!feof(iFile)) {
			fgets(iFile, szBuffer, charsmax(szBuffer));
			trim(szBuffer);

			if(szBuffer[0] == EOS || szBuffer[0] == ';') {
				continue;
			}

			strtok2(szBuffer, szLeft, charsmax(szLeft), szRight, charsmax(szRight), '=', TRIM_FULL);
			remove_quotes(szLeft);

			if(equali(szCurrentMap, szLeft)) {
				remove_quotes(szRight);
				rh_set_mapname(szRight);
				blFound = true;
				break;
			}
		}

		if(!blFound) {
			fprintf(iFile, "^n^"%s^" = ^"%s^"", szCurrentMap, szCurrentMap);
		}

		fclose(iFile);
	}
}