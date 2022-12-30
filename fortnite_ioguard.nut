// guy from fortnite

Msg("FORTNITE IO Guard Bot...\n");

IncludeScript("botbase.nut");

local botbase_ioguard_attack_range = 250;
local botbase_ioguard_health_base = 250;

const IOGUARD_IDLE_SEQUENCE = "Idle1";
const IOGUARD_WALK_SEQUENCE = "RunAIMALL1_SG";

const IOGUARD_ATTACK_SEQUENCE = "grenThrow";
const IOGUARD_RANGEATTACK_SEQUENCE = "shootSMG1s";
const IOGUARD_RANGERELOAD_SEQUENCE = "reload";
const IOGUARD_STUN_SEQUENCE = "physflinch1";

const IOGUARD_ATTACK_SOUND = "Taunt.YetiRoarBeginning";
const IOGUARD_ATTACK_HIT_SOUND = "Taunt.YetiChestHit";
const IOGUARD_PAIN_SOUND = "fortnite/HitMarker_Body_01.wav";

enum GUARD_STATUS
{
	LOW = 0
	MED = 1
	HIGH = 2
}


local IOGUARD_IDLE_SOUND =
[
	"fortnite/vo/IOAgents_2021_Idle_010.wav",
	"fortnite/vo/IOAgents_2021_Idle_020.wav",
	"fortnite/vo/IOAgents_2021_Idle_030.wav",
	"fortnite/vo/IOAgents_2021_Idle_040.wav",
	"fortnite/vo/IOAgents_2021_Idle_050.wav",
];

local IOGUARD_SUS_SOUND =
[
	"fortnite/vo/IOAgents_2021_Suspicious_010.wav",
	"fortnite/vo/IOAgents_2021_Suspicious_020.wav",
	"fortnite/vo/IOAgents_2021_Suspicious_030.wav",
	"fortnite/vo/IOAgents_2021_Suspicious_040.wav",
	"fortnite/vo/IOAgents_2021_Suspicious_050.wav",
];

local IOGUARD_BACKTOIDLE_SOUND =
[
	"fortnite/vo/IOAgents_2021_SuspiciousReturnToIdle_010.wav",
	"fortnite/vo/IOAgents_2021_SuspiciousReturnToIdle_020.wav",
	"fortnite/vo/IOAgents_2021_SuspiciousReturnToIdle_030.wav",
	"fortnite/vo/IOAgents_2021_SuspiciousReturnToIdle_040.wav",
	"fortnite/vo/IOAgents_2021_SuspiciousReturnToIdle_050.wav",
];

local IOGUARD_ALERT_SOUND =
[
	"fortnite/vo/IOAgents_2021_FullAlert_010.wav",
	"fortnite/vo/IOAgents_2021_FullAlert_020.wav",
	"fortnite/vo/IOAgents_2021_FullAlert_030.wav",
	"fortnite/vo/IOAgents_2021_FullAlert_040.wav",
	"fortnite/vo/IOAgents_2021_FullAlert_050.wav",
];

local IOGUARD_ALERTIDLE_SOUND =
[
	"fortnite/vo/IOAgents_2021_FullAlertIdle_010.wav",
	"fortnite/vo/IOAgents_2021_FullAlertIdle_020.wav",
	"fortnite/vo/IOAgents_2021_FullAlertIdle_030.wav",
	"fortnite/vo/IOAgents_2021_FullAlertIdle_040.wav",
	"fortnite/vo/IOAgents_2021_FullAlertIdle_050.wav",
];

local IOGUARD_DEATH_SOUND =
[
	"fortnite/vo/IOAgents_2021_DBNO_Enter_010.wav",
	"fortnite/vo/IOAgents_2021_DBNO_Enter_011.wav",
	"fortnite/vo/IOAgents_2021_DBNO_Enter_012.wav",
	"fortnite/vo/IOAgents_2021_DBNO_Enter_013.wav",
];


class IOGuard extends PuddyBot
{
	function constructor(bot_ent)
	{
		bot = bot_ent;

		move_speed = 300.0;
		turn_rate = 8.0;
		search_dist_z = 128.0;
		search_dist_nearest = 128.0;

		path = [];
		path_index = 0;
		path_reach_dist = 100.0;
		path_target_ent = null;
		path_target_ent_dist = 250.0;
		path_target_pos = null;
		path_update_time_next = Time();
		path_update_time_delay = 0.2;
		path_update_force = true;
		area_list = {};

		seq_idle = bot_ent.LookupSequence(IOGUARD_IDLE_SEQUENCE);
		seq_run = bot_ent.LookupSequence(IOGUARD_WALK_SEQUENCE);
		pose_move_x = bot_ent.LookupPoseParameter("move_x");
		seq_attack = bot_ent.LookupSequence(IOGUARD_ATTACK_SEQUENCE);
		seq_rangeattack = bot_ent.LookupSequence(IOGUARD_RANGEATTACK_SEQUENCE);
		seq_rangereload = bot_ent.LookupSequence(IOGUARD_RANGERELOAD_SEQUENCE);
		seq_stun = bot_ent.LookupSequence(IOGUARD_STUN_SEQUENCE);
		pose_move_x = bot_ent.LookupPoseParameter("move_x");

		debug = false;

		bIsOnFire = false;

		selectvictim_range = 500.0;
		quitvictim_range = 1500.0;

		status = GUARD_STATUS.LOW;

		Spawn();

		// Add behavior that will run every tick
		AddThinkToEnt(bot_ent, "BotThink");		
	}

	function Precache()
	{
		PrecacheModel( "models/mrdedwish/fortnite/outfits/io_guard/io_guard_npc_enemy.mdl" );

		for (local i = 0; i < IOGUARD_IDLE_SOUND.len(); i++)
		{
			PrecacheSound( IOGUARD_IDLE_SOUND[i] );
		}

		for (local i = 0; i < IOGUARD_ALERTIDLE_SOUND.len(); i++)
		{
			PrecacheSound( IOGUARD_ALERTIDLE_SOUND[i] );
		}

		for (local i = 0; i < IOGUARD_SUS_SOUND.len(); i++)
		{
			PrecacheSound( IOGUARD_SUS_SOUND[i] );
		}

		for (local i = 0; i < IOGUARD_BACKTOIDLE_SOUND.len(); i++)
		{
			PrecacheSound( IOGUARD_BACKTOIDLE_SOUND[i] );
		}

		for (local i = 0; i < IOGUARD_ALERT_SOUND.len(); i++)
		{
			PrecacheSound( IOGUARD_ALERT_SOUND[i] );
		}

		for (local i = 0; i < IOGUARD_DEATH_SOUND.len(); i++)
		{
			PrecacheSound( IOGUARD_DEATH_SOUND[i] );
		}

		PrecacheSound( "fortnite/music/IOGuard_Hi.wav" );
		PrecacheSound( "fortnite/music/IOGuard_Med.wav" );
		PrecacheSound( "fortnite/music/IOGuard_Lo.wav" );

		PrecacheSound( "weapons/smg1/smg1_fire1.wav" );
		PrecacheSound( "weapons/smg1/smg1_reload.wav" );

		PrecacheSound( IOGUARD_ATTACK_SOUND );
		PrecacheSound( IOGUARD_ATTACK_HIT_SOUND );
		PrecacheSound( IOGUARD_PAIN_SOUND );

		PrecacheSound( "Powerup.Knockout_Melee_Hit" );

		//PrecacheSound("ui/cyoa_musicdrunkenpipebomb.mp3");
	}

	function Spawn()
	{
		base.Spawn();

		bot.SetHealth(botbase_ioguard_health_base);
		bot.SetMaxHealth(botbase_ioguard_health_base);

		bot.SetCollisionGroup(Constants.ECollisionGroup.COLLISION_GROUP_PLAYER);

		//Msg("IOGUARD NAME: npc_ioguard_" + bot.GetScriptId() + "\n");

		weapon_model = SpawnEntityFromTable("prop_dynamic", 
		{
			origin = bot.GetAttachmentOrigin(bot.LookupAttachment("anim_attachment_RH")),
			angles = bot.GetAbsAngles(),
			model = "models/weapons/w_smg1.mdl",
			effects = Constants.FEntityEffects.EF_BONEMERGE | Constants.FEntityEffects.EF_PARENT_ANIMATES,
		});
		EntFireByHandle( weapon_model, "SetParent", "npc_ioguard_" + bot.GetScriptId(), 0, null, null );
		EntFireByHandle( weapon_model, "SetParentAttachment", "anim_attachment_RH", 0, null, null );

		weapon_bullet = SpawnEntityFromTable("env_gunfire", 
		{
			origin = weapon_model.GetAttachmentOrigin(weapon_model.LookupAttachment("muzzle")),
			angles = weapon_model.GetAttachmentAngles(weapon_model.LookupAttachment("muzzle")),
			target = null,
			minburstsize = 2,
			maxburstsize = 9
			minburstdelay = 2,
			maxburstdelay = 5,
			rateoffire = 10,
			spread = 5,
			bias = 1,
			collisions = 1,
			shootsound = "weapons/smg1/smg1_fire1.wav",
			startdisabled = 1,
			tracertype = "BrightTracer",
		});
		EntFireByHandle( weapon_bullet, "SetParent", "npc_ioguard_" + bot.GetScriptId(), 0, null, null );
		//EntFireByHandle( weapon_bullet, "SetParentAttachmentMaintainOffset", "muzzle", 0, null, null );

		weapon_clip = 45;

		status_text = SpawnEntityFromTable("point_worldtext", 
		{
			origin = bot.GetAttachmentOrigin(bot.LookupAttachment("eyes")) + Vector(0,0,-50),
			angles = QAngle( -bot.GetAbsAngles().x, -bot.GetAbsAngles().y, -bot.GetAbsAngles().z ),
			message = "?",
			textsize = 0,
			color = "255 255 255",
			orientation = "1",
		});
		EntFireByHandle( status_text, "SetParent", "npc_ioguard_" + bot.GetScriptId(), 0, null, null );
		EntFireByHandle( status_text, "SetParentAttachmentMaintainOffset", "eyes", 0, null, null );

		bot.SetModelScale( 1.2, 0 );
	}

	function AlertSound()
	{
		EmitAmbientSoundOn( IOGUARD_ALERT_SOUND[rand() % IOGUARD_ALERT_SOUND.len()], 10.0, 75, 100, bot );

		status = GUARD_STATUS.HIGH;

		// alert another guards
		/*local squadMate = null;
		while ( squadMate = Entities.FindByNameWithin( null, "npc_ioguard_*", bot.GetOrigin(), 2000.0 ) )
		{
			if ( ( squadMate && squadMate.IsValid() ) && squadMate != bot )
			{
				squadMate.GetScriptScope().my_bot.SetVictim( path_target_ent );
			}
		}*/
	}

	function SusSound()
	{
		EmitAmbientSoundOn( IOGUARD_SUS_SOUND[rand() % IOGUARD_SUS_SOUND.len()], 10.0, 75, 100, bot );

		status = GUARD_STATUS.MED;
	}

	function UpdatePath()
	{
		// Clear out the path first
		ResetPath();

		if ( status == GUARD_STATUS.LOW )
		{
			path_target_ent = null;
			if ( patrol_timer.IsElapsed() )
			{
				patrol_timer.Stop();
				if ( bot.GetLastKnownArea() && ( bot.GetLastKnownArea() instanceof CTFNavArea ) )
					path_target_pos = bot.GetLastKnownArea().FindRandomSpot();
			}
			else
			{
				path_target_pos = bot.GetOrigin();
			}
		}
		else
		{
			// If there is a follow entity specified, then the bot will pathfind to the entity
			if ( path_target_ent != null )
			{
				path_target_pos = path_target_ent.GetOrigin();
			}
			else
			{
				path_target_pos = bot.GetOrigin();
				path_target_ent = null;
				return false;
			}
		}

		// Pathfind from the bot's position to the target position
		local pos_start = bot.GetLocomotionInterface().GetFeet();
		local pos_end = path_target_pos;

		local area_start = NavMesh.GetNavArea(pos_start, search_dist_z);
		local area_end = NavMesh.GetNavArea(pos_end, search_dist_z);

		// If either area was not found, try use the closest one
		if (area_start == null)
			area_start = NavMesh.GetNearestNavArea(pos_start, search_dist_nearest, false, true);
		if (area_end == null)
			area_end = NavMesh.GetNearestNavArea(pos_end, search_dist_nearest, false, true);

		// If either area is still missing, then bot can't progress
		if (area_start == null || area_end == null)
			return false;

		// If the start and end area is the same, one path point is enough and all the expensive path building can be skipped
		if (area_start == area_end)
		{
			path.append(PathPoint(area_end, pos_end, Constants.ENavTraverseType.NUM_TRAVERSE_TYPES));
			return true;
		}

		// Build list of areas required to get from the start to the end
		if (!NavMesh.GetNavAreasFromBuildPath(area_start, area_end, pos_end, 0.0, Constants.ETFTeam.TEAM_ANY, false, area_list))
			return false;

		// No areas found? Uh oh
		if (area_list.len() == 0)
			return false;

		// Now build points using the list of areas, which the bot will then follow
		local area_target = area_list["area0"];
		local area = area_target;
		local area_count = area_list.len();

		// Iterate through the list of areas in order and initialize points
		for (local i = 0; i < area_count && area != null; i++)
		{
			path.append(PathPoint(area, area.GetCenter(), area.GetParentHow()));
			area = area.GetParent(); // Advances to the next connected area
		}

		// Reverse the list of path points as the area list is connected backwards
		path.reverse();

		// Now compute accurate path points, using adjacent points + direction data from nav
		local path_first = path[0];
		local path_count = path.len();

		// First point is simply our current position
		path_first.pos = bot.GetLocomotionInterface().GetFeet();
		path_first.how = Constants.ENavTraverseType.NUM_TRAVERSE_TYPES; // No direction specified

		for (local i = 1; i < path_count; i++)
		{
			local path_from = path[i - 1];
			local path_to = path[i];

			// Computes closest point within the "portal" between adjacent areas
			path_to.pos = path_from.area.ComputeClosestPointInPortal(path_to.area, path_to.how, path_from.pos);
		}

		// Add a final point so the bot can precisely move towards the end point when it reaches the final area
		path.append(PathPoint(area_end, pos_end, Constants.ENavTraverseType.NUM_TRAVERSE_TYPES));
	}

	function SelectVictim()
	{
		if ( IsPotentiallyChaseable( path_target_ent ) && !target_focus_timer.IsElapsed() )
			return;

		path_target_ent = null;
		status = GUARD_STATUS.LOW;

		if ( NetProps.GetPropBool(weapon_bullet, "m_bDisabled") == false )
			EntFireByHandle( weapon_bullet, "Disable", "", 0, null, null );

		// look for players
		local newTarget = Entities.FindByClassnameNearest( "player", bot.GetOrigin(), selectvictim_range );
		if ( newTarget != null )
		{
			if ( IsPotentiallyChaseable( newTarget ) )
			{
				path_target_ent = newTarget;
				target_focus_timer.Start( 5.0 );
				AlertSound();
				UpdatePath();
			}
		}
		/*else // look for more guns
		{
			newTarget = Entities.FindByClassnameNearest( "obj_*", bot.GetOrigin(), selectvictim_range );
			if ( newTarget != null )
			{
					path_target_ent = newTarget;
					AlertSound();
					UpdatePath();
			}
		}*/
	}

	function UpdateSurrounding()
	{
		if ( IsPotentiallyChaseable( path_target_ent ) )
			return;

		local newSus = Entities.FindByClassnameNearest( "player", bot.GetOrigin(), selectvictim_range * 1.5 );
		if ( newSus != null )
		{
			if ( IsPotentiallyVisible( newSus ) )
			{
				FaceTowards( newSus.GetOrigin() );
				if ( status != GUARD_STATUS.MED )
					SusSound();
			}
		}
	}

	function UpdateAttack()
	{
		if ( IsStunned() )
			return;

		if ( attack_hit_timer.Running() )
		{
			if ( attack_hit_timer.IsElapsed() )
			{
				MeleeAttack();
			}
		}

		if ( reload_range_timer.Running() )
		{
			if ( reload_range_timer.IsElapsed() )
			{
				ReloadWeapon();
			}
		}

		if ( attack_range_hit_timer.Running() )
		{
			if ( attack_range_hit_timer.IsElapsed() )
			{
				RangeAttack();
			}
		}
	}

	function UpdateStatus()
	{
		switch (status)
		{
			case GUARD_STATUS.LOW:
				EntFireByHandle( status_text, "AddOutput", "message ?", 0, null, null );
				EntFireByHandle( status_text, "SetTextSize", "0", 0, null, null );
				EntFireByHandle( status_text, "SetColor", "255 255 255", 0, null, null );
			break;

			case GUARD_STATUS.MED:
				EntFireByHandle( status_text, "AddOutput", "message ?", 0, null, null );
				EntFireByHandle( status_text, "SetTextSize", "35", 0, null, null );
				EntFireByHandle( status_text, "SetColor", "255 125 125", 0, null, null );
			break;

			case GUARD_STATUS.HIGH:
				EntFireByHandle( status_text, "AddOutput", "message !", 0, null, null );
				EntFireByHandle( status_text, "SetTextSize", "45", 0, null, null );
				EntFireByHandle( status_text, "SetColor", "255 0 0", 0, null, null );
			break;
		}
	}

	function MeleeAttack()
	{
		attack_hit_timer.Stop();

		local bot_pos = bot.EyePosition();
		if (path_target_ent && path_target_ent.IsValid())
		{
			local trace =
			{
				start = bot_pos,
				end = bot_pos + (bot.GetAbsAngles().Forward() * botbase_ioguard_attack_range),
				hullmin = Vector(-16,-16,-32),
				hullmax = Vector(16,16,32),
				mask = Constants.FContents.CONTENTS_SOLID | Constants.FContents.CONTENTS_MOVEABLE | Constants.FContents.CONTENTS_MONSTER | Constants.FContents.CONTENTS_WINDOW | Constants.FContents.CONTENTS_DEBRIS| Constants.FContents.CONTENTS_GRATE, // MASK_SHOT_HULL
				ignore = bot
			};

			if ( debug )
				DebugDrawLine(bot_pos, bot_pos + (bot.GetAbsAngles().Forward() * botbase_ioguard_attack_range), 0, 255, 0, true, 5);

			if ( TraceHull(trace) && ( ("enthit" in trace) && ( trace.enthit == path_target_ent ) ) )
			{
				local vDmgForce = path_target_ent.GetOrigin() - bot_pos;

				path_target_ent.TakeDamageCustom(bot,bot,bot,vDmgForce,trace.pos,path_target_ent.GetMaxHealth() * 0.85,Constants.FDmgType.DMG_CRUSH, Constants.ETFDmgCustom.TF_DMG_CUSTOM_DECAPITATION_BOSS);
				path_target_ent.ApplyAbsVelocityImpulse( vDmgForce * 400 + Vector(0, 0, 400));
				EmitAmbientSoundOn( IOGUARD_ATTACK_HIT_SOUND, 10.0, 100, 100, path_target_ent );
			}
		}
	}

	function RangeAttack()
	{
		attack_range_hit_timer.Stop();

		weapon_bullet.SetAbsAngles( bot.GetAbsAngles() );

		NetProps.SetPropEntity( weapon_bullet, "m_hTarget", path_target_ent );

		EntFireByHandle( weapon_bullet, "Enable", "", 0, null, null );

		if ( weapon_clip <= 0 )
		{
			bot.GetLocomotionInterface().Stop();
			EntFireByHandle( weapon_bullet, "Disable", "", 0, null, null );

			reload_range_timer.Start(bot.GetSequenceDuration(seq_rangereload));
			attack_timer.Start(bot.GetSequenceDuration(seq_rangereload));

			bot.ResetSequence(seq_rangereload);
			if (bot.GetSequence() != seq_rangereload)
				bot.SetSequence(seq_rangereload);
				
			EmitAmbientSoundOn("weapons/smg1/smg1_reload.wav", 10.0, 1000, 100, bot );

			ResetPath();
			path_update_time_next = Time() + bot.GetSequenceDuration(seq_rangereload);
			path_update_force = true;
		}
		else
		{
			weapon_clip -= 1;
		}
		
		DispatchParticleEffect( "muzzle_pistol", weapon_model.GetAttachmentOrigin(weapon_model.LookupAttachment("muzzle")), weapon_model.GetAttachmentOrigin(weapon_model.LookupAttachment("muzzle")) );
		//EmitAmbientSoundOn( "weapons/smg1/smg1_fire1.wav", 10.0, 1500, 100, bot );

		local trace =
		{
			start = bot.EyePosition(),
			end = bot.EyePosition() + (bot.GetAbsAngles().Forward() * 3500.0),
			mask = Constants.FContents.CONTENTS_SOLID | Constants.FContents.CONTENTS_MOVEABLE | Constants.FContents.CONTENTS_MONSTER | Constants.FContents.CONTENTS_WINDOW | Constants.FContents.CONTENTS_DEBRIS| Constants.FContents.CONTENTS_GRATE, // MASK_SHOT_HULL
			ignore = bot
		};

		if (TraceLineEx(trace) && ( ("enthit" in trace ) ) )
		{						
			local vDmgForce = bot.EyePosition() - trace.enthit.GetOrigin();
			trace.enthit.TakeDamageEx(bot,bot,bot,vDmgForce,trace.pos,14,Constants.FDmgType.DMG_BULLET);
		}

		//path_target_ent = null;
	}

	function ReloadWeapon()
	{
		reload_range_timer.Stop();
		weapon_clip = 45;
	}

	function IsAttacking()
	{
		if ( !attack_hit_timer.IsElapsed() )
			return true;

		if ( !attack_range_hit_timer.IsElapsed() )
			return true;

		if ( !stun_timer.IsElapsed() )
			return true;

		if ( !reload_range_timer.IsElapsed() )
			return true;

		return false;
	}

	function IdleSound()
	{
		local time = Time();
		if (idlevo_time_next < time)
		{
			local sound = IOGUARD_IDLE_SOUND[rand() % IOGUARD_IDLE_SOUND.len()];
			if ( path_target_ent != null )
				sound = IOGUARD_ALERTIDLE_SOUND[rand() % IOGUARD_ALERTIDLE_SOUND.len()];
			else
				sound = IOGUARD_IDLE_SOUND[rand() % IOGUARD_IDLE_SOUND.len()];

			EmitAmbientSoundOn( sound, 10.0, 1500, 100, bot );
			idlevo_time_next = time + GetSoundDuration(sound,null) + 10;
		}

		return false;
	}

	function Update()
	{
		SelectVictim();
		UpdateSurrounding();

		if ( !patrol_timer.Running() )
			patrol_timer.Start( 5.0 );

		if ( IsPotentiallyVisible( path_target_ent ) && IsPotentiallyChaseable( path_target_ent ) && ( status != GUARD_STATUS.HIGH ) )
		{
			status = GUARD_STATUS.HIGH;
		}

		switch (status)
		{
			case GUARD_STATUS.LOW:
				EmitAmbientSoundOn("fortnite/music/IOGuard_Lo.wav", 10.0, 4000, 100, bot );
				StopAmbientSoundOn("fortnite/music/IOGuard_Med.wav", bot);
				StopAmbientSoundOn("fortnite/music/IOGuard_Hi.wav", bot);
			break;

			case GUARD_STATUS.MED:
				EmitAmbientSoundOn("fortnite/music/IOGuard_Med.wav", 10.0, 4000, 100, bot );
				StopAmbientSoundOn("fortnite/music/IOGuard_Lo.wav", bot);
				StopAmbientSoundOn("fortnite/music/IOGuard_Hi.wav", bot);
			break;

			case GUARD_STATUS.HIGH:
				EmitAmbientSoundOn("fortnite/music/IOGuard_Hi.wav", 10.0, 4000, 100, bot );
				StopAmbientSoundOn("fortnite/music/IOGuard_Med.wav", bot);
				StopAmbientSoundOn("fortnite/music/IOGuard_Lo.wav", bot);
			break;
		}

		if ( attack_timer.IsElapsed() )
		{
			if (path_target_ent && path_target_ent.IsValid())
			{
				if ((path_target_ent.GetOrigin() - bot.GetOrigin()).Length2D() < botbase_ioguard_attack_range)
				{
					bot.GetLocomotionInterface().Stop();
					FaceTowards( path_target_ent.GetOrigin() );

					if ( debug )
						DebugDrawCircle(bot.GetOrigin(), 0, 255, 0, 128.0, true, 5);

					attack_range_hit_timer.Start( 0.065 );
					attack_timer.Start( 0.1 );

					bot.ResetSequence(seq_rangeattack);
					if (bot.GetSequence() != seq_rangeattack)
						bot.SetSequence(seq_rangeattack);

					ResetPath();
					path_update_time_next = Time() + 1;
					path_update_force = true;
				}
			}
		}

		UpdateStatus();
		UpdateAttack();

		if (CanMove())
		{
			if (Move()) // Try moving
			{
				// Moving, set the run animation
				if (bot.GetSequence() != seq_run)
				{
					bot.SetSequence(seq_run);
					bot.SetPoseParameter(pose_move_x, 1.0); // Set the move_x pose to max weight
				}
			}
			else
			{
				// Not moving, set the idle animation
				if (bot.GetSequence() != seq_idle)
				{
					bot.SetSequence(seq_idle);
				bot.SetPoseParameter(pose_move_x, 0.0); // Clear the move_x pose
				}
				IdleSound();
			}

			// Replay animation if it has finished
			if (bot.GetCycle() > 0.99)
				bot.SetCycle(0.0);
		}

		// Run animations
		bot.StudioFrameAdvance();
		bot.DispatchAnimEvents(bot);

		return 0.0; // Think again next frame
	}

	function Ignite()
	{
		base.Ignite();
		DispatchParticleEffect( "mvm_cash_explosion_embers", bot.GetOrigin(), Vector(0,0,0) );
		//EntFireByHandle( bot, "Ignite", "", 0, null, null );=
	}

	function OnTakeDamage(params)
	{
		DispatchParticleEffect( "blood_impact_red_01", params.damage_position, Vector(0,0,0) );
		EmitAmbientSoundOn( IOGUARD_PAIN_SOUND, 10.0, 1000, 100, bot );

		damage_force = params.damage_force;

		if ( IsPotentiallyVisible( params.attacker ) && ( status == GUARD_STATUS.LOW ) )
		{
			SusSound();
			path_target_ent = params.attacker;
		}

		local weapon = params.weapon;
		if ( weapon && weapon.IsValid() )
		{
			if ( ( params.attacker && params.attacker.IsPlayer() && params.attacker.IsCritBoosted() ) || ( NetProps.GetPropBool(weapon, "m_bCurrentAttackIsCrit") == true ) || params.crit_type == Constants.ECritType.CRIT_FULL 
			|| params.damage_custom == Constants.ETFDmgCustom.TF_DMG_CUSTOM_HEADSHOT 
			|| params.damage_custom == Constants.ETFDmgCustom.TF_DMG_CUSTOM_CLEAVER_CRIT
			|| params.damage_custom == Constants.ETFDmgCustom.TF_DMG_CUSTOM_SHOTGUN_REVENGE_CRIT )
			{
				DispatchParticleEffect( "crit_text", bot.GetAttachmentOrigin(bot.LookupAttachment("eyes")), bot.EyePosition() + Vector(0,0,32) );
				EmitAmbientSoundOn( "TFPlayer.CritHit", 10.0, 75, 100, bot );

				local ItemID = NetProps.GetPropInt(weapon, "m_AttributeManager.m_Item.m_iItemDefinitionIndex")
				if ( ItemID == 656 ) // Holiday Punch
				{
					Stun();
				}
			}

			if ( params.crit_type == Constants.ECritType.CRIT_MINI )
			{
				DispatchParticleEffect( "minicrit_text", bot.GetAttachmentOrigin(bot.LookupAttachment("eyes")), bot.EyePosition() + Vector(0,0,32) );
				EmitAmbientSoundOn( "TFPlayer.CritHitMini", 10.0, 75, 100, bot );
			}
		}
	}

	function OnKilled(params)
	{
		EntFireByHandle( bot, "AddOutput", "rendercolor 100 100 255", 0, null, null );
		weapon_model.Kill();
		weapon_bullet.Kill();
		status_text.Kill();

		StopAmbientSoundOn("fortnite/music/IOGuard_Lo.wav", bot);
		StopAmbientSoundOn("fortnite/music/IOGuard_Med.wav", bot);
		StopAmbientSoundOn("fortnite/music/IOGuard_Hi.wav", bot);
		EmitAmbientSoundOn( IOGUARD_DEATH_SOUND[rand() % IOGUARD_DEATH_SOUND.len()], 10.0, 1000, 100, bot );

		DispatchParticleEffect( "env_sawblood", bot.GetOrigin() + Vector(0,0,32), Vector(0,0,0) );

		base.OnKilled(params);
	}

	function VictimKilled()
	{
		if ( path_target_ent == null )
			return;

		path_target_ent = null;
		EmitAmbientSoundOn( IOGUARD_BACKTOIDLE_SOUND[rand() % IOGUARD_BACKTOIDLE_SOUND.len()], 10.0, 1000, 100, bot );
	}

	attack_timer = Timer();
	attack_hit_timer = Timer();
	attack_range_hit_timer = Timer();
	reload_range_timer = Timer();
	stun_timer = Timer();
	patrol_timer = Timer();

	idlevo_time_next = null;

	seq_rangeattack = null;
	seq_rangereload = null;
	seq_stun = null;

	weapon_model = null;
	weapon_bullet = null;
	weapon_clip = null;

	status = null;
	status_text = null;
}

function SpawnIOGuard()
{
	// Find point where player is looking
	local player = GetListenServerHost();
	local trace =
	{
		start = player.EyePosition(),
		end = player.EyePosition() + (player.EyeAngles().Forward() * 32768.0),
		ignore = player
	};

	if (!TraceLineEx(trace))
	{
		printl("Invalid bot spawn location");
		return null;
	}

	// Spawn bot at the end point
	local bot = SpawnEntityFromTable("base_boss", 
	{
		origin = trace.pos,
		model = "models/mrdedwish/fortnite/outfits/io_guard/io_guard_npc_enemy.mdl",
		playbackrate = 1.0 // Required for animations to be simulated
	});

	EntFireByHandle( bot, "AddOutput", "targetname npc_ioguard_" + bot.GetScriptId(), 0, null, null );

	// Add scope to the entity
	bot.ValidateScriptScope();
	// Append custom bot class and initialize its behavior
	bot.GetScriptScope().my_bot <- IOGuard(bot);

	return bot;
}

SpawnIOGuard();