/**
 * CaseCatalog.ets
 * M2 案件目录：3 个场景、14 个事件节点、9 条线索、4 个结局的本地常量数据。
 *
 * 全部为纯数据，零系统依赖、零网络、零 AI 生成。
 * 事件门槛（requiresClues / requiresFlags / forbiddenFlags）与选项 effects
 * 是「线索与选择真实改变后续事件」的唯一实现依据，与需求说明书第 7 章逐字对应。
 */

import {
  Choice, Clue, Effect, EffectKind, Ending, EventNode, Scene, contains
} from './Models';

// ======================== 目录构造辅助 ========================

function makeEffect(kind: EffectKind, key: string, boolValue: boolean, numValue: number): Effect {
  return { kind: kind, key: key, boolValue: boolValue, numValue: numValue };
}

function addClue(id: string): Effect {
  return makeEffect('ADD_CLUE', id, false, 0);
}

function setFlag(key: string): Effect {
  return makeEffect('SET_FLAG', key, true, 0);
}

function addTrust(delta: number): Effect {
  return makeEffect('ADJUST_TRUST', '', false, delta);
}

function lockEvent(id: string): Effect {
  return makeEffect('LOCK_EVENT', id, false, 0);
}

function unlockEvent(id: string): Effect {
  return makeEffect('UNLOCK_EVENT', id, false, 0);
}

function basicChoice(id: string, text: string, hint: string, effects: Effect[], resultText: string): Choice {
  return {
    id: id, text: text, hint: hint,
    requiresClues: [], requiresFlags: [], forbiddenFlags: [],
    effects: effects, resultText: resultText
  };
}

function gatedChoice(id: string, text: string, hint: string, requiresClues: string[],
                     requiresFlags: string[], forbiddenFlags: string[], effects: Effect[],
                     resultText: string): Choice {
  return {
    id: id, text: text, hint: hint,
    requiresClues: requiresClues, requiresFlags: requiresFlags, forbiddenFlags: forbiddenFlags,
    effects: effects, resultText: resultText
  };
}

function basicEvent(id: string, sceneId: string, title: string, body: string, choices: Choice[]): EventNode {
  return {
    id: id, sceneId: sceneId, title: title, body: body,
    altFlag: '', altBody: '',
    requiresClues: [], requiresFlags: [], forbiddenFlags: [],
    choices: choices
  };
}

function gatedEvent(id: string, sceneId: string, title: string, body: string,
                    requiresClues: string[], requiresFlags: string[], forbiddenFlags: string[],
                    choices: Choice[], altFlag: string, altBody: string): EventNode {
  return {
    id: id, sceneId: sceneId, title: title, body: body,
    altFlag: altFlag, altBody: altBody,
    requiresClues: requiresClues, requiresFlags: requiresFlags, forbiddenFlags: forbiddenFlags,
    choices: choices
  };
}

// ======================== 3 个可探索场景 ========================

export const SCENES: Scene[] = [
  {
    id: 'S1', name: '旧馆 · 阅览室', subtitle: '纸页与借书章',
    description: '校庆前夜的旧馆只亮着两盏灯。台账、过期特刊和被人夹进书里的纸条，都留着没擦干净的痕迹。',
    eventIds: ['E01', 'E02', 'E03', 'E04', 'E05']
  },
  {
    id: 'S2', name: '钟楼 · 活动室', subtitle: '断电的第七盏灯',
    description: '21:40 这里停了电。展台上只剩一圈灰印，值班表被红笔改过，还有人不太愿意开口。',
    eventIds: ['E06', 'E07', 'E08', 'E09']
  },
  {
    id: 'S3', name: '连廊 · 配电间', subtitle: '十四分钟的空白',
    description: '总闸、监控日志、一路延伸的湿鞋印，以及一份没被公示过的备份名单。',
    eventIds: ['E10', 'E11', 'E12', 'E13', 'E14']
  }
];

// ======================== 9 条线索（★ 为定案线索） ========================

export const CLUES: Clue[] = [
  {
    id: 'C1', title: '值日证借阅记录', summary: '21:05 有人借走《校史图册》',
    detail: '旧馆台账上，21:05 的借阅用社员值日证登记，登记人只写了一个「社」字。图册里有历年评优名单的附录。',
    sceneId: 'S1', tag: '人物', weight: 1, fromEventId: 'E02'
  },
  {
    id: 'C2', title: '特刊上的奖杯照片', summary: '底座有一道斜划痕',
    detail: '去年校庆特刊的合影里，奖杯底座有一道从左下到右上的斜划痕；社团群「失窃前」的照片里却没有。',
    sceneId: 'S1', tag: '物证', weight: 1, fromEventId: 'E03'
  },
  {
    id: 'C3', title: '匿名便签', summary: '红字：「21:40 别开灯」',
    detail: '夹在《校史图册》里的便签只有一行红字，笔迹与被涂改的值班表出自同一支笔。',
    sceneId: 'S1', tag: '时间', weight: 2, fromEventId: 'E04'
  },
  {
    id: 'C4', title: '被涂改的值班表', summary: '当晚值班人由林改为周',
    detail: '活动室门口的值班表上，「林」被划掉改成「周」，改动用的是红笔，纸张背面有重描压痕。',
    sceneId: 'S2', tag: '人物', weight: 1, fromEventId: 'E06'
  },
  {
    id: 'C5', title: '★ 奖杯送修回执', summary: '奖杯三天前已送修',
    detail: '社团经费夹最后一页的回执写明：奖杯因底座开裂于三天前送修，签收人一栏是社长。所谓「失窃」并不成立。',
    sceneId: 'S2', tag: '物证', weight: 3, fromEventId: 'E09'
  },
  {
    id: 'C6', title: '配电箱手动跳闸痕迹', summary: '不是故障，是人为拉闸',
    detail: '总闸处于「关」位，闸柄上有新鲜指印，保险丝完好。断电由人为拉闸造成。',
    sceneId: 'S3', tag: '现场', weight: 1, fromEventId: 'E10'
  },
  {
    id: 'C7', title: '★ 监控日志断点', summary: '21:38–21:52 画面中断',
    detail: '监控日志显示 21:38 画面中断、21:52 恢复，中间 14 分钟恰好覆盖便签上的时间。导出完整片段可固定时间线。',
    sceneId: 'S3', tag: '时间', weight: 3, fromEventId: 'E11'
  },
  {
    id: 'C8', title: '★ 备份推荐名单', summary: '与公示名单相差一人',
    detail: '连廊消防门后找回的备份稿里，第九行是另一个名字；公示版在断电当晚被替换过。',
    sceneId: 'S3', tag: '动机', weight: 3, fromEventId: 'E13'
  },
  {
    id: 'C9', title: '湿伞与鞋印', summary: '水迹从活动室延伸到连廊',
    detail: '21:38 前后下过一阵急雨。湿鞋印从活动室一路延伸到连廊尽头的消防门，门后是通往旧馆的捷径。',
    sceneId: 'S3', tag: '现场', weight: 1, fromEventId: 'E12'
  }
];

// ======================== 14 个事件节点 ========================

export const EVENTS: EventNode[] = [
  // ---------- S1 旧馆 · 阅览室 ----------
  basicEvent('E01', 'S1', '深夜的委托',
    '主编把一张便条推到你面前：钟楼活动室 21:40 断电，校庆奖杯和评优推荐名单一起不见了。天亮前，他要一个能刊印的结论。走廊尽头，第七盏灯还亮着。',
    [
      basicChoice('E01-A', '先去借阅台查记录', '记录不会撒谎，先从纸面入手',
        [addClue('C1'), setFlag('accepted'), setFlag('registry_checked'), addTrust(5)],
        '21:05 的借阅记录用的是社员值日证，借的是《校史图册》——那本书的附录里有历年评优名单。线索 +1。'),
      basicChoice('E01-B', '先找当晚值班的同学', '先建立信任，也许能问到更多',
        [setFlag('accepted'), setFlag('asked_first'), addTrust(10)],
        '值班同学只说了一句「那晚灯灭得特别整齐」，便不肯再讲。你决定从别处找证据，信任 +10。')
    ]),

  gatedEvent('E02', 'S1', '借阅台',
    '台账摊在桌上，最后几行墨迹还没干透。管理员说今晚只借出去一本书。',
    [], ['accepted'], [],
    [
      basicChoice('E02-A', '逐页核对值日证', '仔细看编号，别漏掉涂改',
        [addClue('C1'), setFlag('registry_checked')],
        '21:05 那一行用的是值日证，登记人只写了一个「社」字，编号末尾被重描过。'),
      basicChoice('E02-B', '只拍一张照片', '先存证，回头再看',
        [addClue('C1')],
        '你草草拍下台账，没注意角落里被涂改的编号。线索 +1，但少了可核对的细节。')
    ], '', ''),

  gatedEvent('E03', 'S1', '校庆特刊堆',
    '窗边堆着近五年的校庆特刊，最上面一本被翻得卷了角。',
    [], ['accepted'], [],
    [
      basicChoice('E03-A', '翻到奖杯照片那一页', '合影里可能有展台的细节',
        [addClue('C2'), setFlag('photo_seen')],
        '去年合影里，奖杯底座有一道斜划痕；社团群那张「失窃前」的照片里却没有。线索 +1。'),
      basicChoice('E03-B', '略过旧刊物', '时间不多，先去别处',
        [],
        '你把刊物堆推回原处。有些线索一旦错过，就再也补不回来。')
    ], '', ''),

  gatedEvent('E04', 'S1', '夹在书里的便签',
    '《校史图册》的附录页里夹着一张对折的纸，露出红色墨迹的一角。',
    ['C2'], [], [],
    [
      basicChoice('E04-A', '收进证物袋', '先保护来源，别惊动别人',
        [addClue('C3'), setFlag('note_kept'), addTrust(5)],
        '便签上只有一行红字：「21:40 别开灯」。你把它单独夹进采访本，没有声张。'),
      gatedChoice('E04-B', '当场念给大家听', '公开信息，但证人可能改口',
        [], [], [],
        [addClue('C3'), setFlag('exposed_note'), lockEvent('E09'), addTrust(-10)],
        '你把便签念了出来。阅览室安静了一瞬，有人立刻起身往钟楼方向走。信任 -10，一条取证路径被关闭。')
    ], '', ''),

  gatedEvent('E05', 'S1', '林学姐的证词',
    '林学姐在靠窗的位置收拾书包，看见你手里的借阅台账，动作停了一下。',
    ['C1'], [], [],
    [
      gatedChoice('E05-A', '出示借书记录，请她解释', '她与当晚值班表有关',
        [], [], ['exposed_note'],
        [setFlag('trust_lin'), addTrust(15)],
        '她盯着记录看了很久，说那本图册不是她借的，并答应把当晚看见的事写下来。'),
      gatedChoice('E05-B', '先不追问，答应替她保密', '保住证人的名字',
        [], [], ['exposed_note'],
        [setFlag('protected_witness'), setFlag('witness_full'), addTrust(10)],
        '她松了口气，低声说：「名单改过，但别写我的名字。」你点了点头。'),
      gatedChoice('E05-C', '便签公开后，先道歉', '此时她已经不愿再谈',
        [], ['exposed_note'], [],
        [setFlag('witness_recanted')],
        '道歉没能挽回，她只重复「我不记得了」。证词链断了。')
    ], 'exposed_note',
    '林学姐把帽子压低了：「便签的事已经传开了，我什么都不记得。」她改了口，只留下一句「别再问我」。'),

  // ---------- S2 钟楼 · 活动室 ----------
  gatedEvent('E06', 'S2', '被涂改的值班表',
    '门后贴着本周值班表，21:40 那一格被红笔改过，纸面还留着重描的压痕。',
    [], ['accepted'], [],
    [
      basicChoice('E06-A', '核对涂改痕迹', '把笔迹和便签对一下',
        [addClue('C4'), setFlag('roster_checked')],
        '当晚值班人从「林」改成「周」，改动用的红笔和便签是同一支。线索 +1。'),
      basicChoice('E06-B', '直接去问社长', '也许能当场得到解释',
        [addClue('C4'), setFlag('confronted_president'), addTrust(-5)],
        '社长笑了笑说「排班表谁都能改」，然后把门带上了。线索 +1，信任 -5。')
    ], '', ''),

  gatedEvent('E07', 'S2', '奖杯底座',
    '展台空着，只留下一圈浅灰的圆形印子。旁边有人小声说「刚才还在」。',
    ['C2'], [], [],
    [
      basicChoice('E07-A', '比对照片上的划痕', '把物证和特刊合影放在一起看',
        [setFlag('scratch_matched')],
        '灰印尺寸与照片里的底座一致，但划痕方向相反——这里摆过的，是另一个底座。'),
      basicChoice('E07-B', '认定奖杯就是被偷了', '先按最直觉的结论记下',
        [setFlag('assumed_theft')],
        '你先按「失窃」写下结论。这个判断会一直影响后面的推理。')
    ], '', ''),

  gatedEvent('E08', 'S2', '目击者小周',
    '小周抱着一摞社团经费夹站在门口，看见你时往后退了半步。',
    ['C3'], [], [],
    [
      gatedChoice('E08-A', '答应不把他的名字写进稿子', '保护证人，换取材料',
        [], [], ['exposed_note'],
        [setFlag('protected_witness'), addTrust(10)],
        '他犹豫了一下，把经费夹递过来：「你自己看，别说我给的。」'),
      gatedChoice('E08-B', '劝他说出全部，并答应不署名', '把时间线问清楚',
        [], [], ['exposed_note'],
        [setFlag('witness_full'), setFlag('protected_witness'), addTrust(5)],
        '他说 21:38 有人从活动室往连廊走，手里拿着一把湿伞。'),
      gatedChoice('E08-C', '便签公开后，只能先离开', '他不再愿意开口',
        [], ['exposed_note'], [],
        [setFlag('witness_recanted')],
        '他摇头关上了门。你失去了一条通向经费单据的路。')
    ], 'exposed_note',
    '小周看见你就往后退：「便签的事我听说了，我什么都没看见。」他抱紧了经费夹。'),

  gatedEvent('E09', 'S2', '经费单据',
    '经费夹里是这学期的报销单，最后一页似乎还夹着一张不同颜色的回执。',
    ['C4'], ['protected_witness'], [],
    [
      basicChoice('E09-A', '翻到送修回执', '不同颜色的那张纸可能是关键',
        [addClue('C5'), setFlag('repair_found')],
        '三天前，奖杯因底座开裂送修，签收人是社长。所谓「失窃」，从一开始就不成立。★定案线索 +1。'),
      basicChoice('E09-B', '只看支出总额', '时间不多，先记个数',
        [],
        '你合上经费夹，没注意夹在最后一页的回执。')
    ], '', ''),

  // ---------- S3 连廊 · 配电间 ----------
  gatedEvent('E10', 'S3', '配电箱',
    '配电间的门虚掩着，总闸停在「关」位，地面有一小摊雨水。',
    [], ['accepted'], [],
    [
      basicChoice('E10-A', '查看手动跳闸痕迹', '确认是故障还是人为',
        [addClue('C6'), setFlag('power_checked')],
        '总闸被人为拉下，闸柄上还留着新鲜指印，保险丝完好。不是故障。线索 +1。'),
      basicChoice('E10-B', '只看电闸状态', '记下结论就走',
        [addClue('C6')],
        '电闸处在「关」位，你记了下来，但没看出更多。线索 +1。')
    ], '', ''),

  gatedEvent('E11', 'S3', '监控日志',
    '值班室的屏幕停在日志页，21:38 之后是一整段空白。',
    ['C6'], [], [],
    [
      basicChoice('E11-A', '导出 21:30–22:00 片段', '把断点前后的画面连起来',
        [addClue('C7'), setFlag('timeline_fixed')],
        '21:38 中断、21:52 恢复，中间 14 分钟恰好覆盖便签上的时间。时间线被固定下来。★定案线索 +1。'),
      basicChoice('E11-B', '只记下断点', '先记一个时间点',
        [addClue('C7')],
        '你写下「21:38 断」，却没有把前后片段连起来。★线索 +1，但时间线未闭合。')
    ], '', ''),

  gatedEvent('E12', 'S3', '湿伞与鞋印',
    '连廊地砖上有一串没干的水迹，从活动室方向一路往东。',
    ['C7'], [], [],
    [
      basicChoice('E12-A', '沿着水迹走到连廊尽头', '看看它停在哪里',
        [addClue('C9'), setFlag('trail_followed')],
        '水迹止于东侧消防门，门后是通往旧馆的捷径。线索 +1。'),
      basicChoice('E12-B', '拍照存档即可', '留个证据',
        [addClue('C9')],
        '一双湿鞋印，从活动室延伸到连廊。线索 +1。')
    ], '', ''),

  gatedEvent('E13', 'S3', '备份推荐名单',
    '消防门后的纸箱里压着一份没盖章的推荐名单备份稿，和公示版页数一样。',
    ['C7'], [], [],
    [
      basicChoice('E13-A', '逐行比对公示名单', '差异可能就是动机',
        [addClue('C8'), setFlag('names_diff')],
        '备份稿第九行是另一个名字，公示版在断电当晚被替换过。★定案线索 +1。'),
      basicChoice('E13-B', '先收进采访包', '回去再细看',
        [addClue('C8')],
        '你把备份稿收好，暂时没细看。★线索 +1。')
    ], '', ''),

  gatedEvent('E14', 'S3', '第七盏灯',
    '钟楼走廊的第七盏灯亮着。所有纸片摊在地上，只差把它们排成一条时间线。',
    ['C5', 'C8'], ['timeline_fixed'], [],
    [
      basicChoice('E14-A', '还原 21:40 的完整时间线', '把线索排成可刊印的顺序',
        [setFlag('case_ready'), addTrust(20)],
        '21:05 借图册查旧名单 → 21:38 拉闸 → 21:40 换名单、把送修的奖杯说成失窃 → 21:52 恢复供电。证据链闭合。'),
      basicChoice('E14-B', '把线索交给编辑部', '让推理台做最后判断',
        [setFlag('case_ready'), addTrust(5)],
        '你把材料摞齐。够不够刊印，要看推理台上的判断。')
    ], '', '')
];

// ======================== 4 个结局 ========================

export const ENDINGS: Ending[] = [
  {
    id: 'END_TRUTH', title: '灯下的署名', subtitle: '真相 · 证据链闭合',
    body: '稿子在第二天的校刊上印了出来：奖杯三天前已送修，所谓失窃只是为了让那份被换掉的推荐名单显得像一场意外。21:38 有人拉下总闸，21:40 换走名单，21:52 恢复供电。你在文末写了社长的名字，也附上了送修回执、监控日志与备份稿三份证据。第七盏灯在天亮前熄灭，这次是有人主动关的。',
    tone: 'truth'
  },
  {
    id: 'END_PARTIAL', title: '半亮的路灯', subtitle: '残缺 · 证据链有缺口',
    body: '你交出了一份方向大致正确的稿子，但缺了最关键的一两块拼图：没有送修回执、时间线没闭合，或名单差异没被逐行核对。主编读完只说了一句「先压着吧」。钟楼的灯修好了，可走廊尽头那一段，仍旧半明半暗。',
    tone: 'partial'
  },
  {
    id: 'END_MISJUDGE', title: '错指的人', subtitle: '误判 · 指认对象错误',
    body: '你把名字写错了。稿子见报的当天，被指认的同学拿着值班表和借阅台账来找你，一条条说明自己那晚在哪里。主编撤回了稿件，你在更正启事里只写了「证据不足」。走廊的灯照常亮着，只是再没人愿意替你作证。',
    tone: 'misjudge'
  },
  {
    id: 'END_COVER', title: '没有寄出的稿子', subtitle: '断裂 · 证人改口',
    body: '那张便签被念出声之后，证人一个接一个改了口。等你终于拼齐物证，愿意在记录上署名的人已经没有了。稿子写完了，却始终没有寄出。多年以后你仍记得那晚：第七盏灯亮着，只是没人再抬头看它。',
    tone: 'cover'
  }
];

// ======================== 目录查询 ========================

export function findScene(id: string): Scene | null {
  for (let i = 0; i < SCENES.length; i++) {
    if (SCENES[i].id === id) {
      return SCENES[i];
    }
  }
  return null;
}

export function findClue(id: string): Clue | null {
  for (let i = 0; i < CLUES.length; i++) {
    if (CLUES[i].id === id) {
      return CLUES[i];
    }
  }
  return null;
}

export function findEvent(id: string): EventNode | null {
  for (let i = 0; i < EVENTS.length; i++) {
    if (EVENTS[i].id === id) {
      return EVENTS[i];
    }
  }
  return null;
}

export function findChoice(event: EventNode, id: string): Choice | null {
  for (let i = 0; i < event.choices.length; i++) {
    if (event.choices[i].id === id) {
      return event.choices[i];
    }
  }
  return null;
}

export function findEnding(id: string): Ending | null {
  for (let i = 0; i < ENDINGS.length; i++) {
    if (ENDINGS[i].id === id) {
      return ENDINGS[i];
    }
  }
  return null;
}

export function eventsOfScene(sceneId: string): EventNode[] {
  const out: EventNode[] = [];
  for (let i = 0; i < EVENTS.length; i++) {
    if (EVENTS[i].sceneId === sceneId) {
      out.push(EVENTS[i]);
    }
  }
  return out;
}

export function clueTitle(id: string): string {
  const clue: Clue | null = findClue(id);
  return clue === null ? id : clue.title;
}

export function hasClue(stateClues: string[], id: string): boolean {
  return contains(stateClues, id);
}
