// Half Life 2 Zombie
ClearGameEventCallbacks();

IncludeScript("hl2headcrab.nut");

Msg("Zombie Bot...\n");

local ZOMBIE_MELEE_REACH = 55;
local ZOMBIE_HEALTH = 100;

local ZOMBIE_WALK_SEQUENCE =
[
	"walk",
	"walk2",
	"walk3",
	"walk4",
];

local ZOMBIE_ATTACK_SOUND =
[
	"npc/zombie/zo_attack1.wav",
	"npc/zombie/zo_attack2.wav",
];

local ZOMBIE_ATTACK_SEQUENCE =
[
	"attackA",
	"attackB",
	"attackC",
	"attackD",
	"attackE",
	"attackF",
];

local ZOMBIE_ATTACK_HIT_SOUND =
[
	"npc/zombie/claw_strike1.wav",
	"npc/zombie/claw_strike2.wav",
	"npc/zombie/claw_strike3.wav",
];

local ZOMBIE_DEATH_SOUND =
[
	"npc/zombie/zombie_die1.wav",
	"npc/zombie/zombie_die2.wav",
	"npc/zombie/zombie_die3.wav",
];

local ZOMBIE_ALERT_SOUND =
[
	"npc/zombie/zombie_alert1.wav",
	"npc/zombie/zombie_alert2.wav",
	"npc/zombie/zombie_alert3.wav",
];

local ZOMBIE_PAIN_SOUND =
[
	"npc/zombie/zombie_pain1.wav",
	"npc/zombie/zombie_pain2.wav",
	"npc/zombie/zombie_pain3.wav",
	"npc/zombie/zombie_pain4.wav",
	"npc/zombie/zombie_pain5.wav",
	"npc/zombie/zombie_pain6.wav",
];

local ZOMBIE_IDLE_SOUND =
[
	"npc/zombie/zombie_voice_idle1.wav",
	"npc/zombie/zombie_voice_idle2.wav",
	"npc/zombie/zombie_voice_idle3.wav",
	"npc/zombie/zombie_voice_idle4.wav",
	"npc/zombie/zombie_voice_idle5.wav",
	"npc/zombie/zombie_voice_idle6.wav",
	"npc/zombie/zombie_voice_idle7.wav",
	"npc/zombie/zombie_voice_idle8.wav",
	"npc/zombie/zombie_voice_idle9.wav",
	"npc/zombie/zombie_voice_idle10.wav",
	"npc/zombie/zombie_voice_idle11.wav",
	"npc/zombie/zombie_voice_idle12.wav",
	"npc/zombie/zombie_voice_idle13.wav",
	"npc/zombie/zombie_voice_idle14.wav",
];

local ZOMBIE_MOAN_SOUND = "npc/zombie/moan_loop1.wav";


class CZombie extends Bot
{
	function constructor(bot_ent)
	{
		bot = bot_ent;

		move_speed = 50.0;
		turn_rate = 5.0;
		search_dist_z = 128.0;
		search_dist_nearest = 128.0;

		path = [];
		path_index = 0;
		path_reach_dist = 16.0;
		path_target_ent = null;
		path_target_ent_dist = 50.0;
		path_target_pos = null;
		path_update_time_next = Time();
		path_update_time_delay = 0.2;
		path_update_force = true;
		area_list = {};

		seq_idle = bot_ent.LookupSequence("Idle01");
		seq_run = bot_ent.LookupSequence(ZOMBIE_WALK_SEQUENCE[rand() % ZOMBIE_WALK_SEQUENCE.len()]);
		seq_attack = bot_ent.LookupSequence(ZOMBIE_ATTACK_SEQUENCE[rand() % ZOMBIE_ATTACK_SEQUENCE.len()]);
		pose_move_x = bot_ent.LookupPoseParameter("move_x");

		debug = false;

		bIsTorso = false;
		bIsOnFire = false;
		bCanReleaseHeadcrab = true;

		Spawn();

		// Add behavior that will run every tick
		AddThinkToEnt(bot_ent, "BotThink");		
	}

	function Precache()
	{
		PrecacheModel( "models/zombie/classic_torso.mdl" );

		for (local i = 0; i < ZOMBIE_ATTACK_SOUND.len(); i++)
		{
				PrecacheSound( ZOMBIE_ATTACK_SOUND[i] );
		}

		for (local i = 0; i < ZOMBIE_ATTACK_HIT_SOUND.len(); i++)
		{
				PrecacheSound( ZOMBIE_ATTACK_HIT_SOUND[i] );
		}

		for (local i = 0; i < ZOMBIE_DEATH_SOUND.len(); i++)
		{
				PrecacheSound( ZOMBIE_DEATH_SOUND[i] );
		}

		for (local i = 0; i < ZOMBIE_ALERT_SOUND.len(); i++)
		{
				PrecacheSound( ZOMBIE_ALERT_SOUND[i] );
		}

		for (local i = 0; i < ZOMBIE_PAIN_SOUND.len(); i++)
		{
				PrecacheSound( ZOMBIE_PAIN_SOUND[i] );
		}

		for (local i = 0; i < ZOMBIE_IDLE_SOUND.len(); i++)
		{
				PrecacheSound( ZOMBIE_IDLE_SOUND[i] );
		}

		PrecacheSound( ZOMBIE_MOAN_SOUND );
	}

	function Spawn()
	{
		base.Spawn();

		bot.SetHealth(ZOMBIE_HEALTH);
		bot.SetMaxHealth(ZOMBIE_HEALTH);

		bot.SetCollisionGroup(Constants.ECollisionGroup.COLLISION_GROUP_PLAYER);
		bot.SetBodygroup(1, 1); // Headcrab

	}

	function AlertSound()
	{
		EmitAmbientSoundOn( ZOMBIE_ALERT_SOUND[rand() % ZOMBIE_ALERT_SOUND.len()], 10.0, 75, 100, bot );
	}

	function UpdateAttack()
	{
		if ( attack_hit_timer.Running() )
		{
			if ( attack_hit_timer.IsElapsed() )
			{
				attack_hit_timer.Stop();

				local bot_pos = bot.GetOrigin();
				if (path_target_ent && path_target_ent.IsValid())
				{
					local trace =
					{
						start = bot_pos,
						end = bot_pos + (bot.GetAbsAngles().Forward() * ZOMBIE_MELEE_REACH),
						hullmin = Vector(-16,-16,-16),
						hullmax = Vector(16,16,16),
						mask = Constants.FContents.CONTENTS_SOLID | Constants.FContents.CONTENTS_MOVEABLE | Constants.FContents.CONTENTS_MONSTER | Constants.FContents.CONTENTS_WINDOW | Constants.FContents.CONTENTS_DEBRIS| Constants.FContents.CONTENTS_GRATE, // MASK_SHOT_HULL
						ignore = bot
					};

					if (TraceHull(trace) && ( ("enthit" in trace) && ( trace.enthit == path_target_ent ) ) )
					{
						local vDmgForce = bot_pos - path_target_ent.GetOrigin();

						path_target_ent.TakeDamageCustom(bot,bot,bot,vDmgForce,trace.pos,20,Constants.FDmgType.DMG_SLASH, Constants.ETFDmgCustom.TF_DMG_CUSTOM_SPELL_SKELETON);
						path_target_ent.ApplyAbsVelocityImpulse(vDmgForce*-ZOMBIE_MELEE_REACH);
						EmitAmbientSoundOn( ZOMBIE_ATTACK_HIT_SOUND[rand() % ZOMBIE_ATTACK_HIT_SOUND.len()], 5.0, 50, 100, path_target_ent );
					}
				}
			}
		}
	}

	function IsAttacking()
	{
		return !attack_hit_timer.IsElapsed();
	}

	function MoanSound()
	{
		if ( bIsOnFire )
			return;

		local time = Time();
		if (moan_time_next < time)
		{
			local sound = ZOMBIE_IDLE_SOUND[rand() % ZOMBIE_IDLE_SOUND.len()];
			EmitAmbientSoundOn( sound, 10.0, 75, 100, bot );
			moan_time_next = time + GetSoundDuration(sound,null) + 10;
		}

		return false;
	}

	function Update()
	{
		SelectVictim();

		if (attack_timer.IsElapsed() && !IsAttacking() && !bIsOnFire )
		{
			if (path_target_ent && path_target_ent.IsValid())
			{
				if ((path_target_ent.GetOrigin() - bot.GetOrigin()).Length2D() < ZOMBIE_MELEE_REACH)
				{
					bot.GetLocomotionInterface().Stop();
					bot.GetLocomotionInterface().FaceTowards( path_target_ent.GetOrigin() );

					EmitAmbientSoundOn( ZOMBIE_ATTACK_SOUND[rand() % ZOMBIE_ATTACK_SOUND.len()], 10.0, 75, 100, bot );

					if (bot.GetSequence() != seq_attack)
						bot.SetSequence(seq_attack);

					attack_hit_timer.Start( 0.5 );
					attack_timer.Start( bot.GetSequenceDuration(seq_attack) );

					ResetPath();
					path_update_time_next = Time() + bot.GetSequenceDuration(seq_attack) / 2;
					path_update_force = true;
				}
			}
		}

		UpdateAttack();

		if (!IsAttacking())
		{
			if (Move()) // Try moving
			{
				// Moving, set the run animation
				if (bot.GetSequence() != seq_run)
				{
					bot.SetSequence(seq_run);
				}
			}
			else
			{
				// Not moving, set the idle animation
				if (bot.GetSequence() != seq_idle)
				{
					bot.SetSequence(seq_idle);
				}
				MoanSound();
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

	function BecomeTorso()
	{
		bIsTorso = true;
		DispatchParticleEffect( "blood_decap", bot.GetOrigin(), Vector(-90,0,0) );
		bot.SetModel( "models/zombie/classic_torso.mdl" );
		bot.SetSequence( bot.LookupSequence("fall") );

		seq_idle = bot.LookupSequence("Idle01");
		seq_run = bot.LookupSequence("crawl");
		seq_attack = bot.LookupSequence("crawl");
	}

	function Ignite()
	{
		base.Ignite();
		//EmitAmbientSoundOn( ZOMBIE_MOAN_SOUND, 5.0, 50, 100, bot );
		move_speed = 25;
		DispatchParticleEffect( "mvm_cash_explosion_embers", bot.GetOrigin(), Vector(0,0,0) );
		EntFireByHandle( bot, "Ignite", "", 0, null, null );
		seq_idle = bot.LookupSequence("FireIdle");
		seq_run = bot.LookupSequence("FireWalk");
	}

	function OnTakeDamage(params)
	{
		if ( !bIsOnFire )
			EmitAmbientSoundOn( ZOMBIE_PAIN_SOUND[rand() % ZOMBIE_PAIN_SOUND.len()], 10.0, 75, 100, bot );

		DispatchParticleEffect( "spell_skeleton_goop_green", params.damage_position, Vector(0,0,0) );

		if ( params.damage_type & Constants.FDmgType.DMG_BLAST 
		|| params.damage_custom == Constants.ETFDmgCustom.TF_DMG_CUSTOM_PUMPKIN_BOMB 
		|| params.damage_custom == Constants.ETFDmgCustom.TF_DMG_CUSTOM_DECAPITATION 
		|| params.damage_custom == Constants.ETFDmgCustom.TF_DMG_CUSTOM_AIR_STICKY_BURST 
		|| params.damage_custom == Constants.ETFDmgCustom.TF_DMG_CUSTOM_DEFENSIVE_STICKY 
		|| params.damage_custom == Constants.ETFDmgCustom.TF_DMG_CUSTOM_ROCKET_DIRECTHIT 
		|| params.damage_custom == Constants.ETFDmgCustom.TF_DMG_CUSTOM_STANDARD_STICKY 
		|| params.damage_custom == Constants.ETFDmgCustom.TF_DMG_CUSTOM_STICKBOMB_EXPLOSION
		|| params.damage_custom == Constants.ETFDmgCustom.TF_DMG_CUSTOM_PRACTICE_STICKY
		|| params.damage_custom == Constants.ETFDmgCustom.TF_DMG_CUSTOM_EYEBALL_ROCKET
		|| params.damage_custom == Constants.ETFDmgCustom.TF_DMG_CUSTOM_CLEAVER_CRIT
		|| params.damage_custom == Constants.ETFDmgCustom.TF_DMG_CUSTOM_MERASMUS_GRENADE
		|| params.damage_custom == Constants.ETFDmgCustom.TF_DMG_CUSTOM_STICKBOMB_EXPLOSION )
		{
			if ( !bIsTorso )
				BecomeTorso();
		}

		if ( params.damage_custom == Constants.ETFDmgCustom.TF_DMG_CUSTOM_HEADSHOT
		|| params.damage_custom == Constants.ETFDmgCustom.TF_DMG_CUSTOM_BACKSTAB  
		|| params.damage_custom == Constants.ETFDmgCustom.TF_DMG_CUSTOM_DECAPITATION 
		|| params.damage_custom == Constants.ETFDmgCustom.TF_DMG_CUSTOM_TELEFRAG 
		|| params.damage_custom == Constants.ETFDmgCustom.TF_DMG_CUSTOM_DECAPITATION_BOSS 
		|| params.damage_custom == Constants.ETFDmgCustom.TF_DMG_CUSTOM_HEADSHOT_DECAPITATION
		|| params.damage_custom == Constants.ETFDmgCustom.TF_DMG_CUSTOM_MERASMUS_DECAPITATION )
		{
			if ( bCanReleaseHeadcrab )
				bCanReleaseHeadcrab = false;
		}

		base.OnTakeDamage(params);
	}

	function OnKilled(params)
	{
		//StopAmbientSoundOn( ZOMBIE_MOAN_SOUND, bot );

		EmitAmbientSoundOn( ZOMBIE_DEATH_SOUND[rand() % ZOMBIE_DEATH_SOUND.len()], 10.0, 75, 100, bot );

		// Release HEADCRAB
		if ( bCanReleaseHeadcrab )
		{
			bot.SetBodygroup(1, 0);
			local releasedheadcrab = SpawnEntityFromTable("base_boss", 
			{
				targetname = "npc_headcrab",
				model = "models/headcrabclassic.mdl",
				origin = bot.GetAttachmentOrigin(bot.LookupAttachment("headcrab")),
				playbackrate = 1.0,
				health = 50
			});

			releasedheadcrab.ValidateScriptScope();
			releasedheadcrab.GetScriptScope().my_bot <- CHeadcrab(releasedheadcrab);
		}

		//bot.BecomeRagdollOnClient(damage_force);

		base.OnKilled(params);
	}

	attack_timer = Timer();
	attack_hit_timer = Timer();
	moan_time_next = null;

	bIsTorso = null;
	bCanReleaseHeadcrab = null;
}

function SpawnZombie()
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
		targetname = "npc_zombie",
		origin = trace.pos,
		model = "models/zombie/classic.mdl",
		playbackrate = 1.0 // Required for animations to be simulated
	});
	
	// Add scope to the entity
	bot.ValidateScriptScope();
	// Append custom bot class and initialize its behavior
	bot.GetScriptScope().my_bot <- CZombie(bot);

	return bot;
}

SpawnZombie();