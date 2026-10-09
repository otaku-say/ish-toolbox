/* busybox-cbq-compat.h —— CBQ UAPI 兼容块（供 busybox.sh 追加到 linux/pkt_sched.h）
 *
 * 背景（2026-10 实测）：内核 >=6.8 的 UAPI 头删除了 CBQ 段
 * （linux/pkt_sched.h: TC_CBQ_* / tc_cbq_* / TCA_CBQ_*，v6.6 尚在、v6.8 已无），
 * 而 busybox 1.38 的 networking/tc.c 仍引用它们 → 在更新的宿主头文件上编译
 * amd64（musl-gcc + 宿主 UAPI 拷贝）必失败：
 *   networking/tc.c:236:27: error: 'TCA_CBQ_MAX' undeclared ...
 * busybox.sh 在追加前会检查 TCA_CBQ_MAX 是否缺失；本文件亦带 ifndef 守卫（双保险）。
 * 数值取自 Linux 5.15 uapi/linux/pkt_sched.h（CBQ 自 2.4 起数值稳定，未再变更）。
 */
#ifndef TCA_CBQ_MAX

#define TC_CBQ_MAXPRIO		8
#define TC_CBQ_MAXLEVEL		8
#define TC_CBQ_DEF_EWMA		5

struct tc_cbq_lssopt {
	unsigned char	change;
	unsigned char	flags;
#define TCF_CBQ_LSS_BOUNDED	1
#define TCF_CBQ_LSS_ISOLATED	2
	unsigned char	ewma_log;
	unsigned char	level;
#define TCF_CBQ_LSS_FLAGS	1
#define TCF_CBQ_LSS_EWMA	2
#define TCF_CBQ_LSS_MAXIDLE	4
#define TCF_CBQ_LSS_MINIDLE	8
#define TCF_CBQ_LSS_OFFTIME	0x10
#define TCF_CBQ_LSS_AVPKT	0x20
	__u32		maxidle;
	__u32		minidle;
	__u32		offtime;
	__u32		avpkt;
};

struct tc_cbq_wrropt {
	unsigned char	flags;
	unsigned char	priority;
	unsigned char	cpriority;
	unsigned char	__reserved;
	__u32		allot;
	__u32		weight;
};

struct tc_cbq_ovl {
	unsigned char	strategy;
#define	TC_CBQ_OVL_CLASSIC	0
#define	TC_CBQ_OVL_DELAY	1
#define	TC_CBQ_OVL_LOWPRIO	2
#define	TC_CBQ_OVL_DROP		3
#define	TC_CBQ_OVL_RCLASSIC	4
	unsigned char	priority2;
	__u16		pad;
	__u32		penalty;
};

struct tc_cbq_police {
	unsigned char	police;
	unsigned char	__res1;
	unsigned short	__res2;
};

struct tc_cbq_fopt {
	__u32		split;
	__u32		defmap;
	__u32		defchange;
};

struct tc_cbq_xstats {
	__u32		borrows;
	__u32		overactions;
	__s32		avgidle;
	__s32		undertime;
};

enum {
	TCA_CBQ_UNSPEC,
	TCA_CBQ_LSSOPT,
	TCA_CBQ_WRROPT,
	TCA_CBQ_FOPT,
	TCA_CBQ_OVL_STRATEGY,
	TCA_CBQ_RATE,
	TCA_CBQ_RTAB,
	TCA_CBQ_POLICE,
	__TCA_CBQ_MAX,
};

#define TCA_CBQ_MAX	(__TCA_CBQ_MAX - 1)

#endif /* !TCA_CBQ_MAX */
