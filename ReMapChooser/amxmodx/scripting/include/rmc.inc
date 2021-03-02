
#if defined _rmc_included
	#endinput
#endif
#define _rmc_included

forward rmc_timer_started_post();
forward rmc_vote_started_post();
forward rmc_map_chosen_post();
forward rmc_rtv_voted_post();

native rmc_start_vote();
native bool:rmc_is_vote_started();
native bool:rmc_is_map_chosen();
