% =========================================================================
% Script Name: simulate_SigmaX.m
% Description: 千万级城市 Sigma-X 病毒传播动力学仿真 (SEIRV-Delay 模型)
% =========================================================================
clear; clc; close all;

%% 1. 初始条件与仿真参数设定
N = 1e7;          % 城市总人口
I0 = 100;         % 初始感染者
S0 = N - I0;      % 初始易感者
y0 =[S0; 0; 0; 0; I0; 0; 0]; %[S, Sv, E1, E2, I, R, V]

tspan = 0:0.1:200; % 仿真时间跨度，步长0.1天

% 基础参数封装到结构体
params.N = N;
params.beta0 = 0.45;        % 基础传染率 (15人 * 3%)
params.gamma = 1/8;         % I -> R 的康复率
params.sigma1 = 1/4;        % E1 -> E2 转移率 (4天无传染性潜伏期)
params.sigma2 = 1/2;        % E2 -> I 转移率 (2天有传染性潜伏期)
params.c = 0.5;             % E2 的相对传染力系数
params.alpha = 1/14;        % Sv -> V 抗体生成率 (14天滞后)
params.omega = -log(0.9)/150; % R/V -> S 免疫衰减率 (约等于 0.0007)
params.vaccine_doses = 100000; % 日接种剂次
params.vaccine_eff = 0.85;     % 疫苗有效率

%% 2. 执行ODE仿真计算
% 必须在运行前清空子函数中的 persistent 变量，防止上次运行状态残留
clear ode_sys_intervention; 

% 情景 A：实施动态干预
[t_int, y_int] = ode45(@(t,y) ode_sys_intervention(t, y, params), tspan, y0);
I_int = y_int(:, 5); % 提取有干预下的 I(t)

% 情景 B：无干预 (对照组)
[t_no, y_no] = ode45(@(t,y) ode_sys_no_intervention(t, y, params), tspan, y0);
I_no = y_no(:, 5);   % 提取无干预下的 I(t)

%% 3. 数据分析与预测评估
[peak_I_int, idx_int] = max(I_int);
peak_day_int = t_int(idx_int);[peak_I_no, idx_no] = max(I_no);
peak_day_no = t_no(idx_no);

expansion_ratio = peak_I_no / peak_I_int;

fprintf('====== Sigma-X 病毒仿真分析结果 ======\n');
fprintf('[有干预] 疫情最高峰出现在第 %.1f 天，峰值活跃感染人数: %.0f 人\n', peak_day_int, peak_I_int);
fprintf('[无干预] 疫情最高峰出现在第 %.1f 天，峰值活跃感染人数: %.0f 人\n', peak_day_no, peak_I_no);
fprintf('如果不实施动态干预，疫情峰值规模将扩大 %.1f 倍！\n', expansion_ratio);

%% 4. 可视化绘图
figure('Name', 'Sigma-X 病毒动力学仿真', 'Position',[100, 100, 1000, 500]);

% 子图1：各状态演化曲线 (有动态干预)
subplot(1,2,1);
plot(t_int, y_int(:,1)/N, 'LineWidth', 2); hold on;
plot(t_int, y_int(:,3)/N + y_int(:,4)/N, 'LineWidth', 2); % Total E
plot(t_int, y_int(:,5)/N, 'r-', 'LineWidth', 2);
plot(t_int, y_int(:,6)/N, 'g-', 'LineWidth', 2);
plot(t_int, y_int(:,7)/N, 'm-', 'LineWidth', 2);
plot(t_int, y_int(:,2)/N, 'k--', 'LineWidth', 1.5); % Sv state
yline(0.01, 'k:', '1% 管控阈值', 'LineWidth', 1.5);
title('情景 A: 各状态人口比例演化 (含动态干预与疫苗)', 'FontSize', 12);
xlabel('时间 (天)', 'FontSize', 11);
ylabel('人口占比', 'FontSize', 11);
legend('易感态 (S)', '潜伏态 (E_1+E_2)', '感染态 (I)', '康复态 (R)', ...
       '免疫态 (V)', '抗体形成期 (S_V)', 'Location', 'Best');
grid on;

% 子图2：干预 vs 无干预的活跃感染者对比
subplot(1,2,2);
plot(t_int, I_int, 'r-', 'LineWidth', 2); hold on;
plot(t_no, I_no, 'b--', 'LineWidth', 2);
title('情景 B: 动态干预效果对比分析', 'FontSize', 12);
xlabel('时间 (天)', 'FontSize', 11);
ylabel('活跃感染人数 (I)', 'FontSize', 11);
legend('实施动态干预', '无任何干预', 'Location', 'Best');
grid on;


%% =========================================================================
% 局部函数1：带有非线性动态干预的 ODE 微分系统
% =========================================================================
function dydt = ode_sys_intervention(t, y, params)
    % 状态变量分配
    S = y(1); Sv = y(2); E1 = y(3); E2 = y(4); I = y(5); R = y(6); V = y(7);
    
    % 利用 persistent 变量维持状态机的迟滞效应 (Hysteresis Loop)
    persistent policy_mode;
    if isempty(policy_mode)
        policy_mode = 0; % 0: Normal, 1: Strict Control, 2: Relaxed Control
    end
    
    % 计算当前感染比例
    P = I / params.N;
    
    % 状态机逻辑触发判定
    if P > 0.01
        policy_mode = 1; % 触碰1%红线，直接开启严格管控
    elseif P < 0.001 && policy_mode == 1
        policy_mode = 2; % 处于严格管控且降至0.1%以下，政策松动
    end
    
    % 根据当前政策状态设置 beta
    if policy_mode == 0
        beta_current = params.beta0;
    elseif policy_mode == 1
        beta_current = params.beta0 * (1 - 0.75); % 接触骤降 75%
    elseif policy_mode == 2
        beta_current = params.beta0 * 0.50;       % 恢复至初始的 50%
    end
    
    % 计算当前有效疫苗接种率 (仅从第30天开始)
    if t >= 30
        % 假设疫苗等比例作用于易感者 S
        v_rate = params.vaccine_doses * params.vaccine_eff * (S / params.N);
    else
        v_rate = 0;
    end
    
    % 感染力 (Force of Infection)
    lambda = beta_current * (I + params.c * E2) / params.N;
    
    % 微分方程定义
    dS  = -lambda * S - v_rate + params.omega * (R + V);
    dSv = v_rate - lambda * Sv - params.alpha * Sv;
    dE1 = lambda * (S + Sv) - params.sigma1 * E1;
    dE2 = params.sigma1 * E1 - params.sigma2 * E2;
    dI  = params.sigma2 * E2 - params.gamma * I;
    dR  = params.gamma * I - params.omega * R;
    dV  = params.alpha * Sv - params.omega * V;
    
    dydt =[dS; dSv; dE1; dE2; dI; dR; dV];
end

%% =========================================================================
% 局部函数2：无干预下的基线 ODE 微分系统 (用于对照测算)
% =========================================================================
function dydt = ode_sys_no_intervention(t, y, params)
    S = y(1); Sv = y(2); E1 = y(3); E2 = y(4); I = y(5); R = y(6); V = y(7);
    beta_current = params.beta0; % 始终保持无干预高位
    
    if t >= 30
        v_rate = params.vaccine_doses * params.vaccine_eff * (S / params.N);
    else
        v_rate = 0;
    end
    
    lambda = beta_current * (I + params.c * E2) / params.N;
    
    dS  = -lambda * S - v_rate + params.omega * (R + V);
    dSv = v_rate - lambda * Sv - params.alpha * Sv;
    dE1 = lambda * (S + Sv) - params.sigma1 * E1;
    dE2 = params.sigma1 * E1 - params.sigma2 * E2;
    dI  = params.sigma2 * E2 - params.gamma * I;
    dR  = params.gamma * I - params.omega * R;
    dV  = params.alpha * Sv - params.omega * V;
    
    dydt =[dS; dSv; dE1; dE2; dI; dR; dV];
end