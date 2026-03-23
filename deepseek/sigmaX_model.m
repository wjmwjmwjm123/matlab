%% Sigma-X Virus传播模型仿真
% 作者：数学流行病学家与MATLAB仿真工程师
% 日期：2026-03-23
% 描述：针对Sigma-X病毒在千万级城市的传播动力学建模

clear; clc; close all;

%% 参数定义
N = 1e7;                % 总人口
I0 = 100;               % 初始感染者
S0 = N - I0;            % 初始易感者
E10 = 0;                % 初始潜伏期（无传染性）
E20 = 0;                % 初始潜伏期末期（有传染性）
R0 = 0;                 % 初始康复者
V0 = 0;                 % 初始免疫者（疫苗）
J0 = 0;                 % 初始已接种但未免疫者

% 基础传播参数
c0 = 15;                % 基础每日接触人数
p_infect = 0.03;        % 每次接触感染概率
beta0 = c0 * p_infect;  % 感染者传播率（每天）
beta_E = 0.5 * beta0;   % 潜伏期末期传播率（减半）

% 各阶段平均持续时间（天）
tau_E1 = 4;             % 潜伏期无传染性阶段（前4天）
tau_E2 = 2;             % 潜伏期有传染性阶段（后2天）
tau_I = 8;              % 正式感染期

% 转移速率（每天）
sigma1 = 1 / tau_E1;    % E1 -> E2
sigma2 = 1 / tau_E2;    % E2 -> I
gamma = 1 / tau_I;      % I -> R

% 疫苗接种参数
t_vacc_start = 30;      % 疫苗接种开始时间（天）
vacc_rate = 1e5;        % 每日接种人数（人/天）
vacc_eff = 0.85;        % 疫苗保护率
tau_vacc = 14;          % 疫苗产生抗体所需时间（天）
alpha = 1 / tau_vacc;   % 疫苗延迟速率

% 免疫衰减参数
tau_immune = 150;       % 免疫衰减时间（天）
p_loss = 0.1;           % 免疫衰减概率
delta = p_loss / tau_immune; % 免疫衰减率（每天）

% 动态干预阈值
threshold_strict = 0.01;    % 1%，触发严格管控
threshold_relax = 0.001;    % 0.1%，触发政策松动

% 接触人数调整因子
factor_normal = 1.0;        % 正常情况
factor_strict = 0.25;       % 严格管控（减少75%）
factor_relax = 0.5;         % 政策松动（恢复至50%）

% 初始状态向量
y0 = [S0; E10; E20; I0; R0; V0; J0];

% 仿真时间
tspan = [0, 200];       % 200天
opts = odeset('RelTol', 1e-6, 'AbsTol', 1e-6);

%% 使用ode45求解
[t, y] = ode45(@(t,y) ode_system(t, y, N, beta0, beta_E, sigma1, sigma2, gamma, ...
    t_vacc_start, vacc_rate, vacc_eff, alpha, delta, ...
    threshold_strict, threshold_relax, factor_normal, factor_strict, factor_relax), ...
    tspan, y0, opts);

% 提取结果
S = y(:,1);
E1 = y(:,2);
E2 = y(:,3);
I = y(:,4);
R = y(:,5);
V = y(:,6);
J = y(:,7);

% 计算活跃感染者比例
P = I / N;

%% 可视化
figure('Position', [100, 100, 1200, 800]);

% 子图1：各类人群数量随时间变化
subplot(2,2,1);
plot(t, S, 'b-', 'LineWidth', 2); hold on;
plot(t, E1+E2, 'm-', 'LineWidth', 2);
plot(t, I, 'r-', 'LineWidth', 2);
plot(t, R, 'g-', 'LineWidth', 2);
plot(t, V, 'c-', 'LineWidth', 2);
xlabel('时间 (天)');
ylabel('人口数量');
title('Sigma-X病毒传播动力学');
legend('易感者 S', '潜伏期 E', '感染者 I', '康复者 R', '免疫者 V', 'Location', 'best');
grid on;
xlim([0,200]);

% 子图2：感染者比例与干预阈值
subplot(2,2,2);
plot(t, P*100, 'r-', 'LineWidth', 2); hold on;
yline(threshold_strict*100, 'k--', 'LineWidth', 1.5, 'Label', '严格管控阈值 1%');
yline(threshold_relax*100, 'k-.', 'LineWidth', 1.5, 'Label', '政策松动阈值 0.1%');
xlabel('时间 (天)');
ylabel('感染者比例 (%)');
title('感染者比例与干预阈值');
grid on;
xlim([0,200]);

% 子图3：每日新增感染（来自E2->I的流入）
subplot(2,2,3);
new_infections = sigma2 * E2;  % E2 -> I 的转移率即为每日新增感染
plot(t, new_infections, 'r-', 'LineWidth', 2);
xlabel('时间 (天)');
ylabel('每日新增感染人数');
title('每日新增感染人数');
grid on;
xlim([0,200]);

% 子图4：累积感染人数
subplot(2,2,4);
cumulative_infections = N - S - V;  % 总人口减去易感者和免疫者（近似）
plot(t, cumulative_infections, 'k-', 'LineWidth', 2);
xlabel('时间 (天)');
ylabel('累积感染人数');
title('累积感染人数');
grid on;
xlim([0,200]);

%% 输出关键结果
[peak_I, peak_idx] = max(I);
peak_day = t(peak_idx);
fprintf('========== 仿真结果汇总 ==========\n');
fprintf('总人口: %d\n', N);
fprintf('疫情高峰出现在第 %.1f 天\n', peak_day);
fprintf('高峰时感染者人数: %.0f\n', peak_I);
fprintf('高峰时感染者比例: %.2f%%\n', peak_I/N*100);
fprintf('最终易感者比例: %.2f%%\n', S(end)/N*100);
fprintf('最终免疫者比例: %.2f%%\n', V(end)/N*100);
fprintf('最终康复者比例: %.2f%%\n', R(end)/N*100);

%% 对比无干预情况（简化估计）
fprintf('\n========== 无干预情况估计 ==========\n');
R0_eff = (beta_E * tau_E2 + beta0 * tau_I);
final_infected_ratio_no_intervention = 1 - 1/R0_eff;
if final_infected_ratio_no_intervention < 0
    final_infected_ratio_no_intervention = 0.99;
end
if final_infected_ratio_no_intervention > 0.99
    final_infected_ratio_no_intervention = 0.99;
end

fprintf('基本再生数 R0 估计: %.2f\n', R0_eff);
fprintf('无干预下预计最终感染比例: %.1f%%\n', final_infected_ratio_no_intervention*100);
fprintf('无干预下预计感染人数: %.0f\n', final_infected_ratio_no_intervention * N);
fprintf('干预后感染人数: %.0f\n', cumulative_infections(end));
reduction = final_infected_ratio_no_intervention * N - cumulative_infections(end);
reduction_ratio = reduction / (final_infected_ratio_no_intervention * N) * 100;
fprintf('干预减少感染人数: %.0f\n', reduction);
fprintf('干预效果（感染减少比例）: %.1f%%\n', reduction_ratio);

%% 模型验证：人口守恒检查
total_pop = S + E1 + E2 + I + R + V + J;
pop_error = max(abs(total_pop - N));
fprintf('\n========== 模型验证 ==========\n');
fprintf('人口守恒最大误差: %.2e\n', pop_error);
if pop_error < 1e-3
    fprintf('人口守恒性良好。\n');
else
    fprintf('警告：人口守恒误差较大。\n');
end

%% ODE系统定义（局部函数） - 必须放在文件末尾
function dydt = ode_system(t, y, N, beta0, beta_E, sigma1, sigma2, gamma, ...
    t_vacc_start, vacc_rate, vacc_eff, alpha, delta, ...
    threshold_strict, threshold_relax, factor_normal, factor_strict, factor_relax)

    % 状态变量
    S = y(1);   % 易感者
    E1 = y(2);  % 潜伏期（无传染性）
    E2 = y(3);  % 潜伏期末期（有传染性）
    I = y(4);   % 感染者
    R = y(5);   % 康复者
    V = y(6);   % 免疫者（疫苗）
    J = y(7);   % 已接种但未免疫者

    % 计算当前感染者比例
    P = I / N;
    
    % 动态干预逻辑（迟滞效应）
    persistent control_state;
    if isempty(control_state)
        control_state = 0; % 0:正常，1:严格管控，2:政策松动
    end
    
    % 状态转移逻辑
    if control_state == 0 && P > threshold_strict
        control_state = 1; % 进入严格管控
    elseif control_state == 1 && P < threshold_relax
        control_state = 2; % 进入政策松动
    elseif control_state == 2 && P > threshold_strict
        control_state = 1; % 重新进入严格管控
    end
    
    % 根据控制状态确定接触调整因子
    if control_state == 0
        c_factor = factor_normal;
    elseif control_state == 1
        c_factor = factor_strict;
    else % control_state == 2
        c_factor = factor_relax;
    end
    
    % 计算有效传播率
    beta_I = c_factor * beta0;
    beta_E2 = c_factor * beta_E;
    
    % 感染率
    lambda = (beta_E2 * E2 + beta_I * I) / N;
    
    % 疫苗接种项
    if t >= t_vacc_start
        vacc_term = vacc_rate; % 每日接种人数
    else
        vacc_term = 0;
    end
    
    % 疫苗延迟项：已接种者产生抗体
    vacc_delay_term = alpha * J; % J -> V 或 S 的流出
    
    % 免疫衰减项
    immune_loss_R = delta * R;
    immune_loss_V = delta * V;
    
    % 微分方程
    dSdt = -lambda * S - vacc_term + (1 - vacc_eff) * vacc_delay_term + immune_loss_R + immune_loss_V;
    dE1dt = lambda * S - sigma1 * E1;
    dE2dt = sigma1 * E1 - sigma2 * E2;
    dIdt = sigma2 * E2 - gamma * I;
    dRdt = gamma * I - immune_loss_R;
    dVdt = vacc_eff * vacc_delay_term - immune_loss_V;
    dJdt = vacc_term - vacc_delay_term;
    
    dydt = [dSdt; dE1dt; dE2dt; dIdt; dRdt; dVdt; dJdt];
end
