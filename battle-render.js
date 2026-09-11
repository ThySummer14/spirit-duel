import { canUpgradeUnit } from './game-presentation.js?v=048ffabb';
/** 战斗 DOM 表现层；状态由 ctx 动态读取，操作继续委托现有 app/game-core 路径。 */
import { GAME_RULES, getCardDefinition, getValidTargets, getValidCombatTargets,
  isUpgradePending, getUnitKeywordStatuses, getKeywordStatusText, getFormation,
  getUnitDefinition, getCardPlayability, getEffectiveCardCost,
  getKeywordCostReductionLabel, canMulligan, canPlayCard } from './game-core.js?v=048ffabb';
import { gameAudio } from './game-audio.js?v=048ffabb';
import { holoLayers } from './card-holo.js?v=048ffabb';

export function createBattleRenderer(ctx) {
  const { nodes, selectionTarget, currentSelectedCard, frontUidOf, unitByUid, makeStatus, handleUnitClick, startCardTargeting, markDropZones, endTargeting, clearDropZones, performBasicAttack, openRealmPreview, handleRealmClick, getDragTargetMode, markCardDropZones, handleCardClick } = ctx;

  function renderUnit(unit, ownerIndex, placement) {
    const owner = ctx.displayedGame.players[ownerIndex];
    const player = ctx.displayedGame.players[0];
    const card = document.createElement('button');
    const isPlayer = ownerIndex === 0;
    const viewSelectedCardId = ctx.replaySession ? null : ctx.selectedCardId;
    const targetMode = selectionTarget();
    const selectedInstance = currentSelectedCard();
    const definition = selectedInstance && getCardDefinition(selectedInstance.definitionId);
    const validTargets = definition ? getValidTargets(ctx.displayedGame, 0, definition.id) : [];
    const isCombatCardTarget = ownerIndex === 1
      && placement === 'front'
      && definition?.effect === 'assault'
      && getValidCombatTargets(ctx.displayedGame, 0).includes(unit.uid);
    const isValidTarget = isCombatCardTarget || (validTargets.includes(unit.uid)
      && ((isPlayer && ['ally-unit', 'knocked-ally'].includes(targetMode)) || (!isPlayer && targetMode === 'enemy-unit')));
    const viewAttackUnitId = ctx.replaySession ? frontUidOf(player) : ctx.selectedAttackUnitId;
    const canSelectForAttack = !ctx.replaySession && isPlayer && unit.hp > 0 && unit.level >= 1 && !viewSelectedCardId && ctx.displayedGame.currentPlayer === 0 && !ctx.aiBusy;
    const selectedAttacker = unitByUid(player, viewAttackUnitId);
    const attackReady = !ctx.replaySession
      && !viewSelectedCardId
      && ctx.displayedGame.currentPlayer === 0
      && !ctx.aiBusy
      && ctx.displayedGame.winner === null
      && !player.attackUsed
      && player.energy > 0
      && selectedAttacker?.hp > 0
      && selectedAttacker.frozen === 0;
    const willBeHit = ownerIndex === 1 && owner.frontUnitId === unit.uid && unit.hp > 0 && attackReady;
    const isTargetMuted = Boolean(viewSelectedCardId) && !isValidTarget;
    const impact = ctx.visualFeedback.unitImpacts.get(unit.uid);
    // 升级阶段：未激活/可升勾的己方存活角色也要可点（点击即升勾）
    const upgradeSelectable = isPlayer && !ctx.replaySession && !ctx.aiBusy
      && !ctx.selectedCardId && canUpgradeUnit(ctx.displayedGame, unit.uid);
    const isInteractive = isValidTarget || canSelectForAttack || upgradeSelectable;
    const canDragToFront = isPlayer
      && !ctx.replaySession
      && placement === 'reserve'
      && unit.hp > 0
      && unit.level >= 1
      && unit.frozen === 0
      && !viewSelectedCardId
      && ctx.displayedGame.currentPlayer === 0
      && !ctx.aiBusy
      && ctx.displayedGame.winner === null
      && !player.attackUsed
      && player.energy > 0;

    card.type = 'button';
    card.className = 'unit-card';
    card.dataset.owner = isPlayer ? 'player' : 'enemy';
    card.dataset.unitId = unit.uid;
    card.style.setProperty('--unit-accent', unit.color);
    card.classList.toggle('is-front', placement === 'front');
    card.classList.toggle('is-selected', isPlayer && viewAttackUnitId === unit.uid && !viewSelectedCardId && !ctx.replaySession);
    card.classList.toggle('is-target', isValidTarget);
    card.classList.toggle('is-target-muted', isTargetMuted);
    card.classList.toggle('will-be-hit', willBeHit);
    card.classList.toggle('is-away', unit.hp <= 0);
    card.classList.toggle('is-dormant', unit.level < 1);
    // 本家规则：可出击的角色轻微脉动提示
    const attackCapable = isPlayer
      && !ctx.replaySession
      && ctx.displayedGame.currentPlayer === 0
      && !ctx.aiBusy
      && ctx.displayedGame.winner === null
      && !viewSelectedCardId
      && unit.hp > 0
      && unit.level >= 1
      && unit.frozen === 0
      && !player.attackUsed
      && player.energy > 0
      && !isUpgradePending(ctx.displayedGame, 0);
    card.classList.toggle('is-attack-capable', attackCapable);
    card.classList.toggle('is-attacking', Boolean(impact?.isAttacker && !impact.isRemoteAttacker));
    card.classList.toggle('is-remote-attacking', Boolean(impact?.isRemoteAttacker));
    card.classList.toggle('is-keyword-empowered', Boolean(impact?.isKeywordEmpowered));
    card.classList.toggle('is-hit', Boolean(impact && (impact.hpDelta < 0 || impact.shieldDelta < 0)));
    card.classList.toggle('is-healed', Boolean(impact && (impact.hpDelta > 0 || impact.shieldDelta > 0)));
    card.classList.toggle('is-leveling', Boolean(impact?.levelDelta > 0));
    card.classList.toggle('is-knocked-out', Boolean(impact?.knockedOut));
    card.classList.toggle('is-returned', Boolean(impact?.returned));
    card.disabled = !isInteractive;
    card.draggable = canDragToFront;
    card.setAttribute('aria-label', `${unit.name}，${placement === 'front' ? '战斗区' : '准备区'}，${unit.level < 1 ? '未激活' : `${unit.level} 勾玉`}，攻击 ${unit.attack}，生命 ${unit.hp}/${unit.maxHp}${unit.shield ? `，护盾 ${unit.shield}` : ''}${unit.frozen ? `，眩晕 ${unit.frozen} 回合` : ''}，${getUnitKeywordStatuses(owner, unit).map((status) => `${status.label} ${status.detail}`).join('，')}`);
    card.title = `${unit.passive.name}：${unit.passive.text}`;

    const art = document.createElement('span');
    art.className = 'unit-art';
    const image = document.createElement('img');
    image.src = unit.art;
    image.alt = '';
    image.width = 200;
    image.height = 260;
    art.append(image);

    // 名牌：只保留名字与形态名，被动与完整状态移入检视层
    const plate = document.createElement('span');
    plate.className = 'unit-plate';
    const plateName = document.createElement('strong');
    plateName.textContent = unit.name;
    plate.append(plateName);
    if (unit.form) {
      const formName = document.createElement('em');
      formName.textContent = unit.form.name;
      plate.append(formName);
    }

    // 勾玉：紧凑菱形点，悬停看数值
    const pips = document.createElement('span');
    pips.className = 'unit-pips';
    pips.title = `勾玉 ${unit.level} / ${GAME_RULES.maxUnitLevel}`;
    pips.innerHTML = Array.from({ length: GAME_RULES.maxUnitLevel }, (_, index) => (
      `<i${index < unit.level ? ' class="is-filled"' : ''}></i>`
    )).join('');

    // 攻/血角标：叠在立绘两下角，一眼可读
    const stats = document.createElement('span');
    stats.className = 'unit-stats';
    const hpLow = unit.hp > 0 && unit.hp <= Math.max(1, Math.floor(unit.maxHp / 3));
    stats.innerHTML = `<b class="unit-atk" title="攻击">${unit.attack}</b><b class="unit-hp" title="生命"${hpLow ? ' data-low="true"' : ''}>${unit.hp}</b>`;

    const health = document.createElement('span');
    health.className = 'unit-health';
    const healthFill = document.createElement('i');
    healthFill.style.width = `${Math.max(0, (unit.hp / unit.maxHp) * 100)}%`;
    health.append(healthFill);

    // 状态：紧凑徽章 + 完整文本进 title 与检视层；前线/目标/受击威胁由卡片状态样式表达，不再占文字位
    const statuses = document.createElement('span');
    statuses.className = 'unit-statuses';
    // 检视层状态签：{ cls, text }
    const inspectTags = [];
    if (unit.level < 1) {
      statuses.append(makeStatus('眠', 'status-dormant', '未激活：提升勾玉后才可出击、被选中或使用其卡牌'));
      inspectTags.push({ cls: 'status-dormant', text: '未激活 · 0 勾' });
    }
    // 关键词效果：完整说明单独成节
    const keywordNotes = [];
    if (isPlayer && viewAttackUnitId === unit.uid && !viewSelectedCardId && !ctx.replaySession && unit.hp > 0) {
      statuses.append(makeStatus('出', 'status-selected', '待出击'));
      inspectTags.push({ cls: 'chip-ready', text: '待出击' });
    }
    if (isValidTarget) {
      inspectTags.push({ cls: 'chip-target', text: '卡牌目标' });
    }
    if (willBeHit) {
      inspectTags.push({ cls: 'chip-danger', text: '将受击' });
    }
    if (unit.form) {
      statuses.append(makeStatus('形', 'status-form', `形态：${unit.form.name}`));
      inspectTags.push({ cls: 'status-form', text: `形态 · ${unit.form.name}` });
    }
    if (unit.shield > 0) {
      statuses.append(makeStatus(`盾${unit.shield}`, 'status-shield', `护盾 ${unit.shield}`));
      inspectTags.push({ cls: 'status-shield', text: `护盾 ${unit.shield}` });
    }
    if (unit.frozen > 0) {
      statuses.append(makeStatus(`眩${unit.frozen}`,  'status-frozen', `眩晕 ${unit.frozen} 回合`));
      inspectTags.push({ cls: 'status-frozen', text: `眩晕 ${unit.frozen} 回合` });
    }
    if (unit.brittle > 0) {
      statuses.append(makeStatus(`裂${unit.brittle}`, 'status-brittle', `晶裂 ${unit.brittle}`));
      inspectTags.push({ cls: 'status-brittle', text: `晶裂 ${unit.brittle}` });
    }
    getUnitKeywordStatuses(owner, unit).forEach((status) => {
      statuses.append(makeStatus(`${status.label} ${status.detail}`,  `status-${status.id}`, `${status.label} ${status.detail}`));
      keywordNotes.push({ label: status.label, detail: status.detail });
    });
    if (unit.hp <= 0) {
      statuses.append(makeStatus(`归${unit.knockout}`, 'status-away', `气绝，${unit.knockout} 回合后归队`));
      inspectTags.push({ cls: 'status-away', text: `气绝 · ${unit.knockout} 回合后归队` });
    }

    // 检视层：「式神録」卷轴式档案——头像圆徽、大字属性栏、引言式被动、彩色状态签、关键词注记
    const inspect = document.createElement('span');
    inspect.className = 'unit-inspect';
    inspect.setAttribute('aria-hidden', 'true');

    const inspectHead = document.createElement('header');
    inspectHead.className = 'inspect-head';
    const emblem = document.createElement('span');
    emblem.className = 'inspect-emblem';
    const emblemImg = document.createElement('img');
    emblemImg.src = unit.art;
    emblemImg.alt = '';
    emblemImg.width = 96;
    emblemImg.height = 96;
    emblem.append(emblemImg);
    const idBlock = document.createElement('div');
    idBlock.className = 'inspect-id';
    idBlock.innerHTML = `<small>${unit.title} / ${unit.role}</small><strong>${unit.name}</strong>`;
    inspectHead.append(emblem, idBlock);

    const statRow = document.createElement('div');
    statRow.className = 'inspect-statrow';
    statRow.innerHTML = `
      <div class="stat"><b>${unit.attack}</b><small>攻击</small></div>
      <div class="stat"><b>${unit.hp}<i>/${unit.maxHp}</i></b><small>生命</small></div>
      <div class="stat"><b>${unit.level}</b><small>勾玉</small></div>`;

    const inspectPassive = document.createElement('blockquote');
    inspectPassive.className = 'inspect-passive';
    inspectPassive.innerHTML = `<b>${unit.passive.name}</b>${unit.passive.text}`;

    const body = document.createElement('div');
    body.className = 'inspect-body';
    body.append(statRow);
    if (inspectTags.length) {
      const chips = document.createElement('div');
      chips.className = 'inspect-chips';
      inspectTags.forEach((tag) => {
        const chip = document.createElement('span');
        chip.className = `chip ${tag.cls}`;
        chip.textContent = tag.text;
        chips.append(chip);
      });
      body.append(chips);
    }
    body.append(inspectPassive);
    if (keywordNotes.length) {
      const notes = document.createElement('ul');
      notes.className = 'inspect-notes';
      keywordNotes.forEach((note) => {
        const item = document.createElement('li');
        item.innerHTML = `<b>${note.label}</b>${note.detail}`;
        notes.append(item);
      });
      body.append(notes);
    }

    inspect.append(inspectHead, body);

    card.append(art, plate, pips, stats, health, statuses);
    const inspectDock = document.querySelector('#unit-inspect-dock');
    const showInspect = () => {
      if (!inspectDock || document.body.classList.contains('is-dragging')) return;
      inspectDock.replaceChildren(...[...inspect.children].map((child) => child.cloneNode(true)));
      inspectDock.hidden = false;
    };
    const hideInspect = () => { if (inspectDock) inspectDock.hidden = true; };
    card.addEventListener('mouseenter', showInspect);
    card.addEventListener('mouseleave', hideInspect);
    card.addEventListener('focus', showInspect);
    card.addEventListener('blur', hideInspect);

    if (impact && (impact.hpDelta || impact.shieldDelta || impact.levelDelta || impact.knockedOut || impact.returned || impact.isRemoteAttacker || impact.isKeywordEmpowered)) {
      const fxSurface = document.createElement('span');
      fxSurface.className = 'unit-fx-surface';
      fxSurface.classList.toggle('is-remote', Boolean(impact.isRemoteAttacker));
      fxSurface.classList.toggle('is-keyword-empowered', Boolean(impact.isKeywordEmpowered));
      fxSurface.setAttribute('aria-hidden', 'true');
      card.append(fxSurface);
    }

    if (impact && (impact.hpDelta || impact.shieldDelta)) {
      const isHealthChange = impact.hpDelta !== 0;
      const delta = isHealthChange ? impact.hpDelta : impact.shieldDelta;
      const impactNumber = document.createElement('span');
      impactNumber.className = 'impact-number';
      impactNumber.classList.toggle('is-positive', delta > 0);
      impactNumber.classList.toggle('is-shield', !isHealthChange);
      const label = document.createElement('small');
      label.textContent = isHealthChange
        ? (delta > 0 ? '生命恢复' : '受到伤害')
        : (delta > 0 ? '获得护盾' : '护盾破损');
      if (isHealthChange && impact.shieldDelta) label.textContent += ` / 护盾 ${impact.shieldDelta > 0 ? '+' : ''}${impact.shieldDelta}`;
      const value = document.createElement('strong');
      value.textContent = delta > 0 ? `+${delta}` : String(delta);
      // 数字大小随伤害值变化
      const magnitude = Math.min(14, Math.abs(delta)) - Math.min(6, Math.abs(delta));
      impactNumber.style.setProperty('--impact-scale', String(1 + magnitude * 0.06));
      impactNumber.append(label, value);
      card.append(impactNumber);
    }

    const callout = document.createElement('span');
    callout.className = 'unit-action-callout';
    if (impact?.knockedOut) {
      callout.classList.add('is-knockout');
      callout.innerHTML = `<small>气绝 / BREAK</small><strong>气绝 · ${unit.knockout} 回合</strong>`;
    } else if (impact?.levelDelta > 0) {
      callout.classList.add('is-level');
      callout.innerHTML = `<small>勾玉提升 / LEVEL UP</small><strong>${unit.level} 勾玉</strong>`;
    } else if (impact?.returned) {
      callout.classList.add('is-return');
      callout.innerHTML = '<small>重返战场 / RETURN</small><strong>复归</strong>';
    } else if (impact?.isKeywordEmpowered) {
      callout.classList.add('is-empowered');
      callout.innerHTML = impact.isRemoteAttacker
        ? '<small>关键词强化 / EMPOWERED</small><strong>鼓舞远程出击</strong>'
        : '<small>关键词强化 / EMPOWERED</small><strong>鼓舞出击</strong>';
    } else if (impact?.isRemoteAttacker) {
      callout.classList.add('is-remote');
      callout.innerHTML = '<small>远程攻击 / REMOTE</small><strong>远程出击</strong>';
    } else if (impact?.isAttacker) {
      callout.classList.add('is-attack');
      callout.innerHTML = '<small>攻击方 / ATTACKER</small><strong>出击</strong>';
    }
    if (callout.classList.length > 1) card.append(callout);
    card.addEventListener('click', () => handleUnitClick(ownerIndex, unit.uid));
    if (canDragToFront) {
      card.addEventListener('dragstart', (event) => {
        ctx.draggedAttackUnitId = unit.uid;
        ctx.selectedAttackUnitId = unit.uid;
        event.dataTransfer.effectAllowed = 'move';
        event.dataTransfer.setData('text/plain', unit.uid);
        document.body.classList.add('is-dragging');
        startCardTargeting(card, 'unit');
        requestAnimationFrame(() => card.classList.add('is-dragging'));
        markDropZones();
      });
      card.addEventListener('dragend', () => {
        ctx.draggedAttackUnitId = null;
        document.body.classList.remove('is-dragging');
        endTargeting();
        card.classList.remove('is-dragging');
        clearDropZones();
      });
    }
    if (ownerIndex === 1 && placement === 'front' && !ctx.replaySession) {
      // 拖拽己方角色到敌方前线 = 直接出击
      card.addEventListener('dragover', (event) => {
        if (!ctx.draggedAttackUnitId) return;
        event.preventDefault();
        event.dataTransfer.dropEffect = 'move';
        card.classList.add('is-drag-over');
      });
      card.addEventListener('dragleave', (event) => {
        if (!card.contains(event.relatedTarget)) card.classList.remove('is-drag-over');
      });
      card.addEventListener('drop', (event) => {
        event.preventDefault();
        const unitId = ctx.draggedAttackUnitId ?? event.dataTransfer.getData('text/plain');
        ctx.draggedAttackUnitId = null;
        document.body.classList.remove('is-dragging');
        endTargeting();
        clearDropZones();
        if (unitId) performBasicAttack(unitId);
      });
    }
    return card;
  }

  function renderRealmColumn(column, player, ownerIndex) {
    // 幻境以头像下的小方块呈现（mini），旧的大条布局已移除
    // mini 判断必须保留：4f4d573 曾误删此定义，导致打出幻境牌后每次 render 抛
    // ReferenceError，AI 回合循环中断并永久卡死（ctx.aiBusy 无法复位）
    const mini = column.classList.contains('realm-mini-row');
    column.replaceChildren();
    if (!player.realms.length) return;
    player.realms.forEach((realm) => {
      const viewSelectedCardId = ctx.replaySession ? null : ctx.selectedCardId;
      const chip = document.createElement('button');
      const selected = currentSelectedCard();
      const selectedDefinition = selected && getCardDefinition(selected.definitionId);
      const selectedCombatCard = selectedDefinition?.effect === 'assault';
      const attackerId = ctx.replaySession ? frontUidOf(ctx.displayedGame.players[0]) : ctx.selectedAttackUnitId;
      const attacker = unitByUid(ctx.displayedGame.players[0], attackerId);
      const attackReady = ownerIndex === 1
        && !ctx.replaySession
        && !viewSelectedCardId
        && ctx.displayedGame.currentPlayer === 0
        && !ctx.aiBusy
        && ctx.displayedGame.winner === null
        && !ctx.displayedGame.players[0].attackUsed
        && ctx.displayedGame.players[0].energy > 0
        && attacker?.hp > 0
        && attacker.frozen === 0;
      const isCardTarget = ownerIndex === 1
        && selectedCombatCard
        && getValidCombatTargets(ctx.displayedGame, 0).includes(realm.uid);
      const isTarget = attackReady || isCardTarget;
      const impact = ctx.visualFeedback.realmImpacts.get(realm.uid);
      chip.type = 'button';
      chip.className = 'realm-chip';
      chip.dataset.realmId = realm.uid;
      chip.classList.toggle('is-target', isTarget);
      chip.classList.toggle('is-target-muted', Boolean(viewSelectedCardId) && !isCardTarget);
      chip.classList.toggle('is-hit', Boolean(impact?.hpDelta < 0));
      chip.classList.toggle('is-mini', mini);
      chip.disabled = mini ? false : !isTarget;
      const keywordStatus = getKeywordStatusText(realm);
      const keywordSuffix = keywordStatus ? ` · ${keywordStatus}` : '';
      chip.title = `${realm.text}${keywordSuffix}`;
      chip.setAttribute('aria-label', `${realm.name}，幻境耐久 ${realm.hp}/${realm.maxHp}${keywordSuffix}，${realm.text}`);
      chip.innerHTML = `<span class="realm-mini-name">${realm.name}</span><b class="realm-mini-hp">${realm.hp}/${realm.maxHp}</b><span class="realm-keyword-status">${keywordStatus}</span>`;
      if (impact?.hpDelta) {
        const number = document.createElement('span');
        number.className = 'realm-impact-number';
        number.textContent = String(impact.hpDelta);
        chip.append(number);
      }
      chip.addEventListener('click', () => {
        // 迷你方块：可作目标时按目标处理，否则弹出效果预览
        if (mini && !isTarget && !ctx.replaySession) {
          openRealmPreview(realm);
          return;
        }
        handleRealmClick(ownerIndex, realm.uid);
      });
      if (ownerIndex === 1 && !ctx.replaySession) {
        // 拖拽己方角色到敌方幻境 = 指定该幻境出击
        chip.addEventListener('dragover', (event) => {
          if (!ctx.draggedAttackUnitId) return;
          event.preventDefault();
          event.dataTransfer.dropEffect = 'move';
          chip.classList.add('is-drag-over');
        });
        chip.addEventListener('dragleave', (event) => {
          if (!chip.contains(event.relatedTarget)) chip.classList.remove('is-drag-over');
        });
        chip.addEventListener('drop', (event) => {
          event.preventDefault();
          const unitId = ctx.draggedAttackUnitId ?? event.dataTransfer.getData('text/plain');
          ctx.draggedAttackUnitId = null;
          document.body.classList.remove('is-dragging');
          endTargeting();
          clearDropZones();
          if (unitId && getValidCombatTargets(ctx.displayedGame, 0).includes(realm.uid)) performBasicAttack(unitId, realm.uid);
        });
      }
      column.append(chip);
    });
  }

  function renderUnitRow(container, ownerIndex) {
    const owner = ctx.displayedGame.players[ownerIndex];
    const ownerImpacts = [...ctx.visualFeedback.unitImpacts.values()]
      .filter((impact) => impact.playerIndex === ownerIndex);
    if (ownerImpacts.some((impact) => impact.isAttacker)) container.dataset.feedback = 'attacker';
    else if (ownerImpacts.length) container.dataset.feedback = 'target';
    else delete container.dataset.feedback;

    // 先清空再重建：render() 会被操作与反馈定时器反复调用，直接 append 会无限堆叠卡牌
    container.replaceChildren();

    // 准备区展示其余角色；战斗区角色由 renderBattleStrip 单独渲染，避免重复
    const frontUid = frontUidOf(owner);
    owner.units.forEach((unit) => {
      if (unit.uid === frontUid) return;
      container.append(renderUnit(unit, ownerIndex, 'reserve'));
    });
  }

  function renderBattleStrip(container, ownerIndex) {
    const owner = ctx.displayedGame.players[ownerIndex];
    const formation = getFormation(ctx.displayedGame, ownerIndex);
    container.replaceChildren();

    const front = owner.units[formation.frontIndex];
    if (front) {
      container.append(renderUnit(front, ownerIndex, 'front'));
    } else {
      const empty = document.createElement('button');
      empty.type = 'button';
      empty.disabled = ownerIndex !== 1 || !currentSelectedCard() || getCardDefinition(currentSelectedCard().definitionId).effect !== 'assault';
      empty.addEventListener('click', () => ctx.handleCoreTarget());
      empty.className = 'empty-front-slot';
      empty.innerHTML = ownerIndex === 0
        ? '<strong>战斗区空缺</strong><span>拖拽角色到此出击</span>'
        : '<strong>战斗区空缺</strong><span>出击将直击核心</span>';
      container.append(empty);
    }
  }

  function renderUnits() {
    renderUnitRow(nodes.playerUnits, 0);
    renderUnitRow(nodes.enemyUnits, 1);
    renderBattleStrip(nodes.playerBattle, 0);
    renderBattleStrip(nodes.enemyBattle, 1);
    renderRealmColumn(nodes.enemyRealms, ctx.displayedGame.players[1], 1);
    renderRealmColumn(nodes.playerRealms, ctx.displayedGame.players[0], 0);
  }

  function renderHandCard(instance, index, totalCount, freshIds) {
    const definition = getCardDefinition(instance.definitionId);
    const unit = getUnitDefinition(definition.unitId);
    const playability = getCardPlayability(ctx.displayedGame, 0, instance.instanceId);
    const effectiveCost = getEffectiveCardCost(ctx.displayedGame, 0, instance.instanceId);
    const costIsReduced = effectiveCost < definition.cost;
    const costReductionLabel = costIsReduced ? getKeywordCostReductionLabel(definition) : null;
    const playerResponding = ctx.displayedGame.responseWindow?.playerIndex === 0;
    // 开局调度阶段：所有手牌可点击（点击即替换），不受升勾/费用限制
    const mulliganActive = !ctx.replaySession && !ctx.mulliganDismissed && canMulligan(ctx.displayedGame, 0);
    const playable = mulliganActive || (!ctx.replaySession && playability.playable && (!ctx.aiBusy || playerResponding));
    const card = document.createElement('button');
    card.type = 'button';
    card.className = 'hand-card';
    card.style.setProperty('--card-accent', unit.color);
    card.dataset.instanceId = instance.instanceId;
    card.dataset.cardType = definition.type;
    card.dataset.rarity = definition.rarity;
    card.classList.toggle('is-selected', !ctx.replaySession && ctx.selectedCardId === instance.instanceId);
    card.classList.toggle('is-blocked', !playable);
    card.classList.toggle('is-drawn', !ctx.replaySession && freshIds.has(instance.instanceId));
    card.classList.toggle('is-mulligan', !ctx.replaySession && !ctx.mulliganDismissed && canMulligan(ctx.displayedGame, 0));
    // 瞬发牌标识
    const isInstant = definition.keywords.includes('instant');
    card.classList.toggle('is-instant', isInstant);
    // 响应窗口：可响应的响应牌脉冲提示
    const respWindow = ctx.displayedGame.responseWindow;
    const responseMatches = !ctx.replaySession && respWindow?.playerIndex === 0
      && definition.timing === 'response' && definition.responseTo.includes(respWindow.action);
    card.classList.toggle('is-response-ready', responseMatches && playable);
    // 扇形排布：以手牌中位为轴，边缘卡牌微微旋转
    const fanStep = Math.min(2.2, 20 / Math.max(totalCount, 1));
    const mid = (totalCount - 1) / 2;
    card.style.setProperty('--fan-rotate', `${((index - mid) * fanStep).toFixed(2)}deg`);
    card.style.zIndex = String(index + 1);
    card.dataset.block = playable ? 'ready' : playability.code;
    card.disabled = !playable;
    card.setAttribute('aria-disabled', String(!playable));
    card.setAttribute('aria-label', `${definition.name}，${definition.level} 勾玉，消耗 ${effectiveCost} 鬼火，${definition.text}${playable ? '' : `，当前不可用：${ctx.replaySession ? '只读回放' : playability.reason}`}`);
    card.title = ctx.replaySession ? '只读回放中不可操作' : playable ? definition.text : playability.reason;

    const cost = document.createElement('span');
    cost.className = 'card-cost';
    cost.classList.toggle('is-unaffordable', playability.code === 'energy');
    cost.classList.toggle('is-free', costIsReduced);
    cost.innerHTML = `<span>${effectiveCost}</span>`;
    const level = document.createElement('span');
    level.className = 'card-level';
    level.textContent = `${definition.level} 勾`;
    const art = document.createElement('span');
    art.className = 'card-art';
    const image = document.createElement('img');
    image.src = unit.art;
    image.alt = '';
    image.width = 200;
    image.height = 260;
    art.append(image);
    const meta = document.createElement('span');
    meta.className = 'card-meta';
    meta.textContent = `${unit.name} / ${definition.typeLabel}`;
    const name = document.createElement('strong');
    name.className = 'card-name';
    name.textContent = definition.name;
    const availability = document.createElement('span');
    availability.className = 'card-availability';
    const availabilityLabels = {
      ready: '可使用',
      turn: '等待对手',
      energy: '鬼火不足',
      charge: '充能不足',
      'fusion-max': '融合已满',
      'source-away': `${unit.name}气绝`,
      level: `需 ${definition.level} 勾`,
      frozen: `${unit.name}眩晕`,
      'upgrade': '先升勾',
      'source-dormant': '未激活',
      'no-target': '暂无目标',
      finished: '对局结束',
      effect: '效果未接入',
      'response-only': '仅响应牌可用',
      'response-wait': '等待响应',
      'choice-wait': '等待占卜',
      missing: '状态异常',
    };
    availability.textContent = ctx.replaySession
      ? '只读回放'
      : costIsReduced && playable
      ? costReductionLabel ?? '费用减免'
      : availabilityLabels[playable ? 'ready' : playability.code] ?? playability.reason;
    if (isInstant) {
      const instantBadge = document.createElement('span');
      instantBadge.className = 'instant-badge';
      instantBadge.textContent = '瞬发';
      card.append(instantBadge);
    }
    // 卡面外壳：clip-path 必须与扇形 rotate 分层，否则合成层光栅化会吞掉卡面（只剩顶部一小截）
    const body = document.createElement('span');
    body.className = 'card-body';
    body.append(cost, level, art, meta, name, availability);
    card.append(body);
    // 拖拽施放：需要选目标且当前可用的手牌，可直接拖到目标身上触发
    const dragMode = getDragTargetMode(definition);
    card.draggable = Boolean(playable && dragMode);
    if (playable && dragMode) {
      card.addEventListener('dragstart', (event) => {
        ctx.draggedCardInstanceId = instance.instanceId;
        event.dataTransfer.effectAllowed = 'move';
        event.dataTransfer.setData('text/plain', instance.instanceId);
        document.body.classList.add('is-dragging');
        startCardTargeting(card, 'card');
        requestAnimationFrame(() => card.classList.add('is-dragging'));
        markCardDropZones(definition);
      });
      card.addEventListener('dragend', () => {
        ctx.draggedCardInstanceId = null;
        document.body.classList.remove('is-dragging');
        endTargeting();
        card.classList.remove('is-dragging');
        clearDropZones();
      });
    }
    card.addEventListener('click', () => handleCardClick(instance));
    card.addEventListener('mouseenter', () => showHandPreview(instance));
    card.addEventListener('focus', () => showHandPreview(instance));
    card.addEventListener('mouseleave', hideHandPreview);
    card.addEventListener('blur', hideHandPreview);
    return card;
  }

  function showHandPreview(instance) {
    const definition = getCardDefinition(instance.definitionId);
    const unit = getUnitDefinition(definition.unitId);
    const effectiveCost = getEffectiveCardCost(ctx.displayedGame, 0, instance.instanceId);
    const tags = definition.tags.map((tag) => `<span>${tag}</span>`).join('');
    const holoClass = instance.isHolo
      ? ` is-holo ${definition.rarity === 'epic' ? 'is-holo-epic' : 'is-holo-rare'}`
      : '';
    nodes.handPreview.innerHTML = `
      <div class="hand-preview-card${holoClass}" data-card-type="${definition.type}" data-rarity="${definition.rarity}" style="--card-accent:${unit.color}">
        <span class="card-art"><img src="${unit.art}" alt="" width="200" height="260"></span>
        <span class="card-cost"><span>${effectiveCost}</span></span>
        <span class="card-level">${definition.level} 勾 · ${definition.typeLabel}</span>
        <span class="card-meta">${unit.name} / ${unit.title}</span>
        <strong class="card-name">${definition.name}</strong>
        <span class="card-text">${definition.text}</span>
        <span class="card-tags">${instance.isHolo ? '<span class="holo-tag">闪卡</span>' : ''}${tags}</span>
      </div>`;
    nodes.handPreview.firstElementChild?.append(...holoLayers(instance.isHolo === true));
    nodes.handPreview.classList.add('is-visible');
  }

  function hideHandPreview() {
    nodes.handPreview.classList.remove('is-visible');
  }

  function renderHand() {
    hideHandPreview();
    const hand = ctx.displayedGame.players[0].hand;
    const freshIds = new Set(hand
      .map((card) => card.instanceId)
      .filter((instanceId) => !ctx.lastHandInstanceIds.has(instanceId)));
    if (!ctx.replaySession && freshIds.size && ctx.lastHandInstanceIds.size > 0) gameAudio.cardDraw();
    ctx.lastHandInstanceIds = new Set(hand.map((card) => card.instanceId));
    // 本家规则：手牌按所属式神分组排列，同式神相邻
    const orderedHand = [...hand].sort((first, second) => {
      const unitDelta = getCardDefinition(first.definitionId).unitId.localeCompare(getCardDefinition(second.definitionId).unitId);
      return unitDelta !== 0 ? unitDelta : hand.indexOf(first) - hand.indexOf(second);
    });
    // 整卡宽度与横向滚动由布局层管理，不按张数缩小或切片。
    nodes.playerHand.style.removeProperty('--hand-scale');
    nodes.playerHand.replaceChildren(...orderedHand.map((instance, index) => renderHandCard(instance, index, orderedHand.length, freshIds)));
    const playerResponding = ctx.displayedGame.responseWindow?.playerIndex === 0;
    nodes.playableCardCount.textContent = ctx.replaySession ? 0 : hand.filter((card) => (
      canPlayCard(ctx.displayedGame, 0, card.instanceId) && (!ctx.aiBusy || playerResponding)
    )).length;
    if (hand.length === 0) {
      const empty = document.createElement('p');
      empty.className = 'empty-hand';
      empty.textContent = '手牌已空';
      nodes.playerHand.append(empty);
    }
  }

  return { renderUnit, renderRealmColumn, renderUnitRow, renderBattleStrip, renderUnits, renderHandCard, showHandPreview, hideHandPreview, renderHand };
}
