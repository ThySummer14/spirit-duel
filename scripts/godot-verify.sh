#!/usr/bin/env bash
# Headless verify for the Godot vertical slice.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="${GODOT_BIN:-/Users/thysummer/apps/Godot.app/Contents/MacOS/Godot}"

if [[ ! -x "$GODOT" ]]; then
  echo "Godot binary not found: $GODOT" >&2
  exit 1
fi

run_godot_check() {
  local check_log check_status check_line
  check_log="$(mktemp)"
  if "$GODOT" --headless --path "$ROOT/godot" "$@" >"$check_log" 2>&1; then
    check_status=0
  else
    check_status=$?
  fi
  cat "$check_log"
  while IFS= read -r check_line; do
    case "$check_line" in
      *"SCRIPT ERROR:"*|*"ERROR:"*) check_status=1 ;;
    esac
  done <"$check_log"
  rm -f "$check_log"
  return "$check_status"
}

if command -v node >/dev/null 2>&1; then
  echo "== export content =="
  node "$ROOT/scripts/export-godot-content.mjs"
fi

echo "== godot import assets =="
run_godot_check --editor --import

for check_script in verify verify_card_aura verify_huibishou verify_coin_river verify_wind_night_mask verify_eye_crab verify_bond_dream verify_monk_cleaner verify_tree_sakura verify_owl_insect verify_moon_bamboo verify_pipe_fox verify_oni_asura verify_rebirth verify_fox_lotus verify_raccoon verify_samurai verify_mountain_realm verify_maple verify_ghost_mountain_maple verify_paint verify_star_bear verify_pine verify_paint_star_pine verify_sparrow verify_headless verify_yaksha verify_night_trio verify_puppet verify_enma verify_weaver verify_fusion_trio verify_goldfish verify_vine verify_wind_raccoon verify_goldfish_vine_wind verify_onikiri verify_otakemaru verify_house verify_sword_house_trio verify_three_tail verify_glutton verify_doll verify_fox_glutton_doll verify_spider_lily verify_cotton verify_butterfly verify_garuda verify_yitiao verify_jorogumo verify_whale verify_crocodile verify_baize verify_susanoo verify_koi_fragrance verify_toxic_pair verify_silk_ninja verify_sea_butterfly verify_lantern verify_futakuchi verify_box_maiden verify_black_white verify_two_faces verify_mianqiling verify_red_purple verify_blue_green verify_mirror_song verify_charged_pair verify_arakawa verify_zhenjian_duel verify_rednight_walnut verify_ape_sleeve verify_cooking_core verify_sugar_cat verify_rabbit_tide verify_food_cross verify_ability_sources verify_heptet_cross verify_octet_cross verify_yi verify_restoration_cross verify_link_cross verify_yujiazhu verify_combat verify_growth verify_draw verify_resource_effects verify_self_damage verify_instant verify_instant_feedback_ui verify_battle_status verify_battle_status_ui verify_auto_targets verify_signed_debuff verify_bounce verify_team_shield verify_turn_order verify_steel_wind verify_steel_wind_ui verify_yaoginshi verify_yaoginshi_ui verify_datiangou verify_datiangou_ui verify_yimulian verify_yimulian_ui verify_zhen verify_zhen_ui verify_phoenix verify_phoenix_ui verify_peach verify_peach_ui verify_firefly verify_firefly_ui verify_yaodao verify_yaodao_ui verify_shuten verify_shuten_ui verify_bingyong verify_bingyong_ui verify_classic_core verify_archer_mountain verify_archer_mountain_ui verify_judge_tide verify_judge_tide_ui verify_snow_crane verify_snow_crane_ui verify_yijin verify_yijin_ui verify_xuenv verify_xuenv_ui verify_dog_demon verify_dog_demon_ui verify_dog_demon_sun verify_light_healer verify_light_healer_ui verify_poison_pair verify_poison_pair_ui verify_book_jue verify_book_jue_ui verify_fortune_pair verify_fortune_pair_ui verify_mode_scope verify_classic_continuation verify_fox_suzuka verify_fox_suzuka_ui verify_sun_smoke verify_sun_smoke_ui verify_movement verify_movement_ui verify_movement_continuation verify_tomato_fire verify_tomato_fire_ui verify_wave2_continuation verify_armor_blood verify_armor_blood_continuation verify_armor_blood_ui verify_huang verify_huang_ui verify_langyazi verify_guishihei verify_treasure verify_insight verify_astral verify_chen verify_rain verify_bone verify_water_moon verify_lunar_cat_izanami verify_yanmie_trio verify_yanmie_trio_ui verify_gift_energy verify_gift_energy_ui verify_charm_realms verify_scroll_wind_faction verify_dusk_grove verify_wave7_reworks verify_dragon_abyss verify_mengpo verify_mengpo_ui verify_armor_limit verify_blessing_continuation verify_armor_limit_ui verify_parallel_rules verify_ui verify_save verify_collection verify_interactions verify_reference_workflow verify_presentation verify_spell_effects verify_aim_pointer verify_video_layout verify_shenqilou verify_formation_edit verify_art verify_roster; do
  echo "== godot $check_script =="
  run_godot_check --script "res://scripts/$check_script.gd"
done
for check_script in verify_slayer_duo verify_coffin verify_commission verify_hanafuda verify_cosmos_dragons verify_cosmos_native verify_cosmos_market verify_star_realms verify_star_realms_ui; do
  echo "== godot $check_script =="
  run_godot_check --script "res://scripts/$check_script.gd"
done
for check_script in verify_destiny_choice verify_time_rewind verify_time_rewind_ui verify_grudge verify_xuan verify_shenqi_huang verify_shenqi_huang_ui verify_baize_yuanqi verify_himiko verify_himiko_ui verify_luohou; do
  echo "== godot $check_script =="
  run_godot_check --script "res://scripts/$check_script.gd"
done
for check_script in verify_cooperation verify_coop_first verify_coop_middle verify_coop_late verify_coop_late_ui; do
  echo "== godot $check_script =="
  run_godot_check --script "res://scripts/$check_script.gd"
done
echo "== godot seeded matches =="
run_godot_check --script res://scripts/playtest_burst.gd -- 60
run_godot_check --script res://scripts/playtest_focus.gd -- 20
echo "== godot boot smoke =="
run_godot_check --quit-after 1
echo "GODOT_VERIFY_ALL_OK"
