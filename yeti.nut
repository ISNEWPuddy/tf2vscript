// Yeti Boss
//Msg("Yeti Bot...\n");

DoIncludeScript("botbase.nut", null);

local botbase_yeti_attack_range = 200;
local botbase_yeti_health_base = 3000;

local botbase_yeti_min_player_count = 10;
local botbase_yeti_health_per_player = 200;

const YETI_IDLE_SEQUENCE = "Stand_MELEE";
const YETI_WALK_SEQUENCE = "Run_MELEE";

const YETI_ATTACK_SEQUENCE = "taunt_bare_knuckle_beatdown_outro";
const YETI_GROUNDPOUND_SEQUENCE = "taunt_yeti";
const YETI_GRABPLAYER_SEQUENCE = "taunt_headbutt_success";
const YETI_STUN_SEQUENCE = "taunt_the_scaredycat_heavy";

const YETI_ATTACK2_SEQUENCE = "taunt_yetipunch";
const YETI_ATTACK4_SEQUENCE = "taunt07_Halloween";
const YETI_ATTACK6_SEQUENCE = "taunt_table_flip_outro";

const YETI_ATTACK_SOUND = "Taunt.YetiRoarBeginning";
const YETI_ATTACK_HIT_SOUND = "Taunt.YetiChestHit";
const YETI_DEATH_SOUND = "MatchMaking.MedalClickRareYeti";
const YETI_ALERT_SOUND = "Taunt.YetiRoarBeginning";
const YETI_PAIN_SOUND = "Taunt.YetiRoarBeginning";

local YETI_IDLE_SOUND =
[
	"Taunt.YetiRoarFirst",
	"Taunt.YetiRoarSecond",
];


class Yeti extends PuddyBot
{
	function constructor(bot_ent)
	{
		bot = bot_ent;

		move_speed = 400.0;
		turn_rate = 8.0;
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

		seq_idle = bot_ent.LookupSequence(YETI_IDLE_SEQUENCE);
		seq_run = bot_ent.LookupSequence(YETI_WALK_SEQUENCE);
		pose_move_x = bot_ent.LookupPoseParameter("move_x");
		seq_attack = bot_ent.LookupSequence(YETI_ATTACK_SEQUENCE);
		seq_groundpound = bot_ent.LookupSequence(YETI_GROUNDPOUND_SEQUENCE);
		seq_grabplayer = bot_ent.LookupSequence(YETI_GRABPLAYER_SEQUENCE);
		seq_stun = bot_ent.LookupSequence(YETI_STUN_SEQUENCE);
		pose_move_x = bot_ent.LookupPoseParameter("move_x");

		debug = false;

		bIsOnFire = false;

		selectvictim_range = 1500.0;
		quitvictim_range = 2000.0;

		yeti_model = null;
		home_pos = null;

		Spawn();

		// Add behavior that will run every tick
		AddThinkToEnt(bot_ent, "BotThink");		
	}

	function Precache()
	{
		PrecacheModel( "models/player/items/taunts/yeti/yeti.mdl" );

		for (local i = 0; i < YETI_IDLE_SOUND.len(); i++)
		{
			if ( IsSoundPrecached( YETI_IDLE_SOUND[i] )  )
				bot.PrecacheScriptSound( YETI_IDLE_SOUND[i] );
		}

		bot.PrecacheScriptSound( YETI_ATTACK_SOUND );
		bot.PrecacheScriptSound( YETI_ATTACK_HIT_SOUND );
		bot.PrecacheScriptSound( YETI_DEATH_SOUND );
		bot.PrecacheScriptSound( YETI_ALERT_SOUND );
		bot.PrecacheScriptSound( YETI_PAIN_SOUND );

		bot.PrecacheScriptSound( "Taunt.YetiLand" );
		bot.PrecacheScriptSound( "Taunt.YetiGroundPound" );
		bot.PrecacheScriptSound( "Powerup.Knockout_Melee_Hit" );
		bot.PrecacheScriptSound( "Taunt.YetiAppearSnow" );
		//bot.PrecacheScriptSound( "Yeti.StatueGrowl" );
		bot.PrecacheScriptSound( "taunt_headbutt_sfx_head_impact" );
		bot.PrecacheScriptSound( "TFPlayer.StunImpact" );
		bot.PrecacheScriptSound( "Halloween.Merasmus_Stun" );

		//PrecacheSound("ui/cyoa_musicdrunkenpipebomb.mp3");
	}

	function Spawn()
	{
		base.Spawn();

		local bossHealth = botbase_yeti_health_base;
		for (local i = 1; i <= Constants.Server.MAX_PLAYERS; i++)
		{
			local player = PlayerInstanceFromIndex(i)
			if (player == null) continue
			{
				if ( i > botbase_yeti_min_player_count )
				{
					bossHealth += ( i - botbase_yeti_min_player_count ) * botbase_yeti_health_per_player;
				}
			}
		}

		bot.SetHealth(bossHealth);
		bot.SetMaxHealth(bossHealth);

		bot.SetCollisionGroup(Constants.ECollisionGroup.COLLISION_GROUP_PLAYER);

		local healthBar = Entities.FindByClassname(null, "monster_resource");
		if (healthBar && healthBar.IsValid)
		{
			NetProps.SetPropInt(healthBar, "m_iBossHealthPercentageByte", 255.0 * 1 );
		}

		yeti_model = SpawnEntityFromTable("prop_dynamic", 
		{
			origin = bot.GetOrigin(),
			angles = bot.GetAbsAngles(),
			model = "models/player/items/taunts/yeti/yeti.mdl",
			effects = Constants.FEntityEffects.EF_BONEMERGE | Constants.FEntityEffects.EF_PARENT_ANIMATES,
		});
		EntFireByHandle( yeti_model, "SetParent", "npc_yeti_" + bot.GetScriptId(), 0, null, null );
		EntFireByHandle( yeti_model, "SetParentAttachment", "head", 0, null, null );

		home_pos = bot.GetOrigin();

		bot.SetModelScale( 1.65, 0 );
		SendGlobalGameEvent( "teamplay_broadcast_audio", {team = -1, sound = "Taunt.YetiAppearSnow"} );
		DispatchParticleEffect( "xms_snowburst", bot.GetOrigin() + Vector(0,0,50), Vector(0,0,0) );
		DispatchParticleEffect( "taunt_yeti_flash", bot.GetOrigin(), Vector(0,0,0) );

		//Say(null,"The YETI has appeared!\n", false);

		//SendGlobalGameEvent( "pumpkin_lord_summoned", {} );
		SendGlobalGameEvent( "player_connect_client", {name = "THE YETI"} );
	}

	function AlertSound()
	{
		EmitAmbientSoundOn( YETI_ALERT_SOUND, 10.0, 75, 100, bot );
	}

	function IsPotentiallyChaseable(victim)
	{
		if ( victim == null )
			return false;

		//if ( !IsPotentiallyVisible( victim ) )
			//return false;

		if ( NetProps.GetPropInt(victim, "m_lifeState") > 0 ) // 0-LIFE_ALIVE  1-LIFE_DYING
			return false;

		if ( NetProps.GetPropInt(victim, "m_Shared.m_nPlayerState") != 0 ) // TF_STATE_ACTIVE
			return false;

		if ( victim.GetHealth() == 0 )
			return false;

		if ( victim.GetTeam() == bot.GetTeam() )
			return false;

		if ((bot.GetOrigin() - victim.GetOrigin()).Length() > 2000.0)
			return false;

		if ( victim.IsPlayer() )
		{
			if ( victim.IsInvulnerable() )
				return false;

			//if ( !( victim.GetFlags() & Constants.FPlayer.FL_ONGROUND ) )
			//{
			//	Vector victimAreaPos;
			//	victimArea->GetClosestPointOnArea( victim->GetAbsOrigin(), &victimAreaPos );
			//	if ( ( victim->GetAbsOrigin() - victimAreaPos ).AsVector2D().IsLengthGreaterThan( 50.0f ) )
			//	{
			//		// off the mesh and unreachable - pick a new victim
			//		return false;
			//	}
			//}

			if ( victim.InAirDueToExplosion() )
				return false;

			if ( victim.InCond(Constants.ETFCond.TF_COND_HALLOWEEN_GHOST_MODE) )
				return false;
		}

		if ( victim.GetLastKnownArea() && ( victim.GetLastKnownArea() instanceof CTFNavArea ) )
		{
			if ( victim.GetLastKnownArea().HasAttributeTF( Constants.FTFNavAttributeType.TF_NAV_SPAWN_ROOM_BLUE | Constants.FTFNavAttributeType.TF_NAV_SPAWN_ROOM_RED ) )
				return false;

			if ( victim.GetLastKnownArea().IsPotentiallyVisibleToTeam( bot.GetTeam() ) )
				return true;

			if ( victim.GetLastKnownArea().IsReachableByTeam( bot.GetTeam() ) )
				return true;
		}

		return true;
	}

	function UpdateAttack()
	{
		if ( IsStunned() )
			return;

		if ( !attack_specialattack_timer.Running() )
			attack_specialattack_timer.Start( 15.0 );

		if ( attack_timer.IsElapsed() )
		{
			if (path_target_ent && path_target_ent.IsValid())
			{
				if ((path_target_ent.GetOrigin() - bot.GetOrigin()).Length2D() < botbase_yeti_attack_range)
				{
					bot.GetLocomotionInterface().Stop();
					FaceTowards( path_target_ent.GetOrigin() );

					if ( attack_specialattack_timer.IsElapsed() )
					{
						attack_specialattack_timer.Stop();
						local grabbableTarget = Entities.FindByClassnameNearest( "player", bot.GetOrigin(), 128.0 );
						if ( debug )
							DebugDrawCircle(bot.GetOrigin(), 0, 255, 0, 128.0, true, 5);

						if ( ( grabbableTarget && grabbableTarget.IsValid() ) && IsPotentiallyChaseable( grabbableTarget ) )
						{
							path_target_ent = grabbableTarget;
							if ( grabbableTarget.GetPlayerClass() != Constants.ETFClass.TF_CLASS_SOLDIER )
								EntFireByHandle( grabbableTarget, "SpeakResponseConcept", "HalloweenLongFall", 0, null, null );
							else
								EntFireByHandle( grabbableTarget, "SpeakResponseConcept", "TLK_PLAYER_PAIN", 0, null, null );

							//grabbableTarget.SetForcedTauntCam( 1 );
							attack_grabplayer_hit_timer.Start( 1.9 );
							attack_timer.Start( 6 );

							EmitAmbientSoundOn( "Taunt.YetiRoarFirst", 10.0, 1000, 100, bot );

							bot.ResetSequence(seq_grabplayer);
							if (bot.GetSequence() != seq_grabplayer)
								bot.SetSequence(seq_grabplayer);

							ResetPath();
							path_update_time_next = Time() + 7;
							path_update_force = true;
						}
						else
						{
							attack_groundslam_hit_timer.Start( 5.4 );
							attack_timer.Start( 7 );

							EmitAmbientSoundOn( "Taunt.YetiRoarSecond", 10.0, 1000, 100, bot );

							bot.ResetSequence(seq_groundpound);
							if (bot.GetSequence() != seq_groundpound)
								bot.SetSequence(seq_groundpound);

							ResetPath();
							path_update_time_next = Time() + 7;
							path_update_force = true;
						}
					}
					else
					{
						EmitAmbientSoundOn( YETI_ATTACK_SOUND, 10.0, 1000, 100, bot );

						bot.ResetSequence(seq_attack);
						if (bot.GetSequence() != seq_attack)
							bot.SetSequence(seq_attack);

						attack_hit_timer.Start( 0.2 );
						attack_timer.Start( 1.2 );

						ResetPath();
						path_update_time_next = Time() + 0.5;
						path_update_force = true;
					}
				}
			}
		}

		if ( attack_hit_timer.Running() )
		{
			if ( attack_hit_timer.IsElapsed() )
			{
				MeleeAttack();
			}
		}

		if ( attack_groundslam_hit_timer.Running() )
		{
			if ( attack_groundslam_hit_timer.IsElapsed() )
			{
				GroundPoundAttack();
			}
		}

		if ( attack_grabplayer_hit_timer.Running() )
		{
			if (path_target_ent != null)
			{
				path_target_ent.SetOrigin(bot.GetAttachmentOrigin( bot.LookupAttachment( "effect_hand_R" ) ) - Vector( 0, 0, 35 ));

				if ( attack_grabplayer_hit_timer.IsElapsed() )
				{
					HeadbuttAttack();
				}
			}
			else
			{
				attack_grabplayer_hit_timer.Stop();
			}
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
				end = bot_pos + (bot.GetAbsAngles().Forward() * botbase_yeti_attack_range),
				hullmin = Vector(-16,-16,-32),
				hullmax = Vector(16,16,32),
				mask = Constants.FContents.CONTENTS_SOLID | Constants.FContents.CONTENTS_MOVEABLE | Constants.FContents.CONTENTS_MONSTER | Constants.FContents.CONTENTS_WINDOW | Constants.FContents.CONTENTS_DEBRIS| Constants.FContents.CONTENTS_GRATE, // MASK_SHOT_HULL
				ignore = bot
			};

			if ( debug )
				DebugDrawLine(bot_pos, bot_pos + (bot.GetAbsAngles().Forward() * botbase_yeti_attack_range), 0, 255, 0, true, 5);

			if ( TraceHull(trace) && ( ("enthit" in trace) && ( trace.enthit == path_target_ent ) ) )
			{
				local vDmgForce = path_target_ent.GetOrigin() - bot_pos;

				path_target_ent.ApplyPunchImpulseX(4);
				path_target_ent.ApplyAbsVelocityImpulse( vDmgForce * 400 + Vector(0, 0, 400));
				path_target_ent.TakeDamageCustom(bot,bot,bot,vDmgForce,trace.pos,path_target_ent.GetMaxHealth() * 0.85,Constants.FDmgType.DMG_CRUSH, Constants.ETFDmgCustom.TF_DMG_CUSTOM_DECAPITATION_BOSS);
				EmitAmbientSoundOn( YETI_ATTACK_HIT_SOUND, 10.0, 100, 100, path_target_ent );
			}
		}
	}

	function GroundPoundAttack()
	{
		attack_groundslam_hit_timer.Stop();
		path_target_ent = null;

		DispatchParticleEffect( "hammer_impact_button", bot.GetOrigin(), Vector(0,0,0) );
		DispatchParticleEffect( "taunt_yeti_fistslam", bot.GetOrigin(), Vector(0,0,0) );
		//DispatchParticleEffect( "mvm_soldier_shockwave", bot.GetOrigin(), Vector(0,0,0) );
		EmitAmbientSoundOn( "Taunt.YetiLand", 10.0, 100, 2000, bot );
		EmitAmbientSoundOn( "Taunt.YetiGroundPound", 10.0, 4000, 100, bot );
		EmitAmbientSoundOn( "Powerup.Knockout_Melee_Hit", 10.0, 2000, 100, bot );
		ScreenShake(bot.GetOrigin(), 5.0, 5.0, 1.0, 1500.0, 0, false);

		local targetEnemies = null;
		local targetDamage = 100;

		if ( debug )
			DebugDrawCircle(bot.GetOrigin(), 0, 255, 0, 300.0, true, 5);

		while ( targetEnemies = Entities.FindInSphere( targetEnemies, bot.GetOrigin(), 330.0 ) )
		{
			if ( targetEnemies.IsPlayer() )
			{
				targetDamage = 25;
				targetEnemies.ApplyAbsVelocityImpulse((targetEnemies.GetOrigin() - bot.GetOrigin()) + Vector(0, 0, 400));
				targetEnemies.ApplyPunchImpulseX(10);
				targetEnemies.AddCondEx(Constants.ETFCond.TF_COND_FREEZE_INPUT, 1.2, bot);
				targetEnemies.AddCondEx(Constants.ETFCond.TF_COND_STUNNED, 1.2, bot);
				EntFireByHandle( targetEnemies, "SpeakResponseConcept", "TLK_PLAYER_PAIN", 0, null, null );
				//EmitSoundOnClient( "Powerup.Knockout_Melee_Hit", targetEnemies );
			}
			targetEnemies.TakeDamageCustom(bot,bot,bot,Vector(0, 0, 0),Vector(0, 0, 0),targetDamage,Constants.FDmgType.DMG_CRUSH, Constants.ETFDmgCustom.TF_DMG_CUSTOM_DECAPITATION_BOSS);
		}
	}

	function HeadbuttAttack()
	{
		attack_grabplayer_hit_timer.Stop();

		DispatchParticleEffect( "taunt_headbutt_impact", bot.GetAttachmentOrigin(bot.LookupAttachment("head")), Vector(0,0,0) );
		DispatchParticleEffect( "mvm_soldier_shockwave", bot.GetAttachmentOrigin(bot.LookupAttachment("head")), Vector(0,0,0) );
		EmitAmbientSoundOn( YETI_ATTACK_HIT_SOUND, 10.0, 100, 1000, bot );
		EmitAmbientSoundOn( "Powerup.Knockout_Melee_Hit", 10.0, 1000, 100, bot );

		EmitAmbientSoundOn( "taunt_headbutt_sfx_head_impact", 10.0, 100, 1000, path_target_ent );

		//path_target_ent.SetForcedTauntCam(0);
		path_target_ent.TakeDamageCustom(bot,bot,bot,Vector(0, 0, 0),Vector(0, 0, 0),path_target_ent.GetMaxHealth() * 2,Constants.FDmgType.DMG_CRUSH, Constants.ETFDmgCustom.TF_DMG_CUSTOM_DECAPITATION_BOSS);
		path_target_ent = null;
	}

	function HealingSequence()
	{
		NetProps.SetPropInt(healthBar, "m_iBossState", 1 );
	}

	function IsAttacking()
	{
		if ( !attack_hit_timer.IsElapsed() )
			return true;

		if ( !attack_groundslam_hit_timer.IsElapsed() )
			return true;

		if ( !attack_grabplayer_hit_timer.IsElapsed() )
			return true;

		if ( IsStunned() )
			return true;

		return false;
	}

	function CanMove()
	{
		if ( IsAttacking() )
			return false;

		if ( IsStunned() )
			return false;

		return true;
	}

	function IsStunned()
	{
		if ( !stun_timer.IsElapsed() )
			return true;

		return false;
	}

	function IdleSound()
	{
		local time = Time();
		if (idlevo_time_next < time)
		{
			local sound = YETI_IDLE_SOUND[rand() % YETI_IDLE_SOUND.len()];
			EmitAmbientSoundOn( sound, 10.0, 1500, 100, bot );
			ScreenShake(bot.GetOrigin(), 2.0, 2.0, 2.0, 1500.0, 0, false);
			idlevo_time_next = time + GetSoundDuration(sound,null) + 10;
		}

		return false;
	}

	function Update()
	{
		SelectVictim();

		UpdateAttack();

		if ( bot.GetLocomotionInterface().IsStuck() && ( bot.GetLocomotionInterface().GetStuckDuration() > 5.0 ) )
		{
			bot.SetOrigin(home_pos);
			bot.GetLocomotionInterface().ClearStuckStatus("Yeti goes home.");
		}

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
				ScreenShake(bot.GetOrigin(), 1.0, 1.0, 1.0, 500.0, 0, false);
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

	function Stun()
	{
		if ( !stun_timer.IsElapsed() )
			return;

		//path_target_ent.SetForcedTauntCam( 0 );
		path_target_ent = null;
		attack_grabplayer_hit_timer.Stop();

		attack_timer.Stop();
		attack_specialattack_timer.Stop();
		attack_groundslam_hit_timer = Timer();

		DispatchParticleEffect( "bonk_text", bot.GetAttachmentOrigin(bot.LookupAttachment("head")), bot.EyePosition() + Vector(0,0,32) );
		stun_timer.Start( 5.8 );
		EmitAmbientSoundOn( "TFPlayer.StunImpact", 10.0, 2000, 100, bot );
		EmitAmbientSoundOn( "Halloween.Merasmus_Stun", 10.0, 2000, 100, bot );
		bot.ResetSequence(seq_stun);
		if (bot.GetSequence() != seq_stun)
			bot.SetSequence(seq_stun);

		ResetPath();
		path_update_time_next = Time() + 5.8;
		path_update_force = true;
	}

	function OnTakeDamage(params)
	{
		local healthBar = Entities.FindByClassname(null, "monster_resource");
		if (healthBar && healthBar.IsValid)
		{
			local healthPercentage = params.const_entity.GetHealth().tofloat() / params.const_entity.GetMaxHealth().tofloat();
			if ( healthPercentage <= 0.0 )
			{
				NetProps.SetPropInt(healthBar, "m_iBossHealthPercentageByte", 0 );
				NetProps.SetPropInt(healthBar, "m_iBossStunPercentageByte", 0 );
				return 0;
			}
			else
			{
				NetProps.SetPropInt(healthBar, "m_iBossHealthPercentageByte", 255.0 * healthPercentage );
			}
		}

		DispatchParticleEffect( "blood_impact_red_01", params.damage_position, Vector(0,0,0) );
		EmitAmbientSoundOn( YETI_PAIN_SOUND, 10.0, 1000, 100, bot );

		damage_force = params.damage_force;

		local weapon = params.weapon;
		if ( weapon && weapon.IsValid() )
		{
			if ( ( params.attacker && params.attacker.IsPlayer() && params.attacker.IsCritBoosted() ) || ( NetProps.GetPropBool(weapon, "m_bCurrentAttackIsCrit") == true ) || params.crit_type == Constants.ECritType.CRIT_FULL 
			|| params.damage_custom == Constants.ETFDmgCustom.TF_DMG_CUSTOM_HEADSHOT 
			|| params.damage_custom == Constants.ETFDmgCustom.TF_DMG_CUSTOM_CLEAVER_CRIT
			|| params.damage_custom == Constants.ETFDmgCustom.TF_DMG_CUSTOM_SHOTGUN_REVENGE_CRIT )
			{
				DispatchParticleEffect( "crit_text", bot.GetAttachmentOrigin(bot.LookupAttachment("head")), bot.EyePosition() + Vector(0,0,32) );
				EmitAmbientSoundOn( "TFPlayer.CritHit", 10.0, 75, 100, bot );

				local ItemID = NetProps.GetPropInt(weapon, "m_AttributeManager.m_Item.m_iItemDefinitionIndex")
				if ( ( attack_grabplayer_hit_timer.Running() && ( params.attacker == path_target_ent ) ) || ItemID == 656 ) // Holiday Punch
				{
					Stun();
					//Say(null,"" + path_target_ent + " has stunned THE YETI\n\n", false);
				}
				else
				{
					if ( IsPotentiallyChaseable( params.attacker ) )
						path_target_ent = params.attacker;
				}
			}

			if ( params.crit_type == Constants.ECritType.CRIT_MINI )
			{
				DispatchParticleEffect( "minicrit_text", bot.GetAttachmentOrigin(bot.LookupAttachment("head")), bot.EyePosition() + Vector(0,0,32) );
				EmitAmbientSoundOn( "TFPlayer.CritHitMini", 10.0, 75, 100, bot );
			}
		}
	}

	function OnKilled(params)
	{
		if ( path_target_ent != null )
			path_target_ent.SetForcedTauntCam(0);

		//StopAmbientSoundOn("ui/cyoa_musicdrunkenpipebomb.mp3", bot);
		SendGlobalGameEvent( "teamplay_broadcast_audio", {team = -1, sound = YETI_DEATH_SOUND} );

		DispatchParticleEffect( "env_sawblood", bot.GetOrigin() + Vector(0,0,32), Vector(0,0,0) );
		DispatchParticleEffect( "xms_snowburst", bot.GetOrigin() + Vector(0,0,50), Vector(0,0,0) );

		local healthBar = Entities.FindByClassname(null, "monster_resource");
		if (healthBar && healthBar.IsValid)
		{
			NetProps.SetPropInt(healthBar, "m_iBossHealthPercentageByte", 0 );
			NetProps.SetPropInt(healthBar, "m_iBossStunPercentageByte", 0 );
		}

		yeti_model.Kill();

		//Say(null,"The YETI has been defeated!\n", false);
		//SendGlobalGameEvent( "pumpkin_lord_killed", {} );
		SendGlobalGameEvent( "player_disconnect", {name = "THE YETI", reason = "Defeated by the mercenaries."} );

		base.OnKilled(params);
	}

	attack_timer = Timer();
	attack_hit_timer = Timer();
	attack_specialattack_timer = Timer();
	attack_groundslam_hit_timer = Timer();
	attack_grabplayer_hit_timer = Timer();

	idlevo_time_next = null;

	seq_groundpound = null;
	seq_grabplayer = null;

	yeti_model = null;
	home_pos = null;
}

function KillYeti()
{
	local boss = Entities.FindByClassname(null, "base_boss");
	if ( boss && boss.IsValid && HasBotScript(boss) )
	{
		boss.TakeDamage(boss.GetMaxHealth(),Constants.FDmgType.DMG_CRUSH, null);
	}

}

::SpawnYeti <- function()
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
		printl("Invalid YETI spawn location");
		return null;
	}

	// Spawn bot at the end point
	local bot = SpawnEntityFromTable("base_boss", 
	{
		origin = trace.pos,
		model = "models/player/heavy.mdl",
		rendermode = 10,
		playbackrate = 1.0 // Required for animations to be simulated
	});

	EntFireByHandle( bot, "AddOutput", "targetname npc_yeti_" + bot.GetScriptId(), 0, null, null );

	// Add scope to the entity
	bot.ValidateScriptScope();
	// Append custom bot class and initialize its behavior
	bot.GetScriptScope().my_bot <- Yeti(bot);

	return bot;
}

function SpawnYetiAtPos()
{
	if ( self && self.IsValid() )
	{
		local bot = SpawnEntityFromTable("base_boss", 
		{
			origin = self.GetOrigin(),
			angles = self.GetAbsAngles(),
			model = "models/player/heavy.mdl",
			rendermode = 10,
			playbackrate = 1.0 // Required for animations to be simulated
		});

		EntFireByHandle( bot, "AddOutput", "targetname npc_yeti_" + bot.GetScriptId(), 0, null, null );

		// Add scope to the entity
		bot.ValidateScriptScope();
		// Append custom bot class and initialize its behavior
		bot.GetScriptScope().my_bot <- Yeti(bot);
	}
	else
	{
		printl("Invalid YETI spawn entity");
	}
}

SpawnYetiAtPos();