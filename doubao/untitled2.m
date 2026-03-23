%% Sigma-X病毒传播动力学仿真脚本
% 可直接运行，MATLAB R2016b及以上版本支持脚本内嵌局部函数
clear; clc; close all;
%% ======================== 1. 参数定义 ========================
N = 1e7;                 % 城市总人口
I0 = 100;                % 初始感染者数量
beta_I = 15 * 0.03;      % 单个正式感染者日均有效接触数
beta_E = 0.5 * beta_I;   % 单个潜伏后期感染者日均有效接触数
sigma1 = 1/4;            % 潜伏前期→后期转移速率 (平均4天)
sigma2 = 1/2;            % 潜伏后期→感染期转移速率 (平均2天)
gamma = 1/8;             % 感染期→康复期转移速率 (平均8天)
omega = 0.1 / 150;       % 免疫衰减速率 (150天后10%失活)
eta = 0.85;              % 疫苗保护率
v_rate = 1e5;            % 日均接种人数
tau_vax = 30;            % 疫苗接种启动时间
tspan = 0:0.1:200;       % 仿真时间：200天，输出步长0.1天
%% ======================== 2. 初始条件 ========================
y0 = zeros(20, 1);       % 20个状态变量：S,E1,E2,I,R,V,U1~U14
y0(1) = N - I0;          % 初始易感人群 = 总人口 - 初始感染者
y0(4) = I0;              % 初始正式感染者
%% ======================== 3. 有干预仿真 ========================
control_enabled = true;
clear sigmaX_ode;  % 清空持久化变量，避免上次仿真残留
[t1, y1] = ode45(@(t,y) sigmaX_ode(t,y,N,beta_E,beta_I,sigma1,sigma2,gamma,omega,eta,v_rate,tau_vax,control_enabled), tspan, y0);
% 提取各人群时间序列
S1 = y1(:,1);
E_total1 = y1(:,2) + y1(:,3);  % 总潜伏人群 = E1+E2
I1 = y1(:,4);
R1 = y1(:,5);
V1 = y1(:,6);
% 计算峰值信息
[peak_I1, peak_idx1] = max(I1);
peak_day1 = t1(peak_idx1);
fprintf('===== 有动态干预结果 =====\n');
fprintf('感染高峰出现在第 %.1f 天\n', peak_day1);
fprintf('峰值感染人数：%.0f 人（占总人口 %.2f%%）\n', peak_I1, peak_I1/N*100);
fprintf('200天末康复人数：%.0f 人\n', R1(end));
fprintf('200天末疫苗免疫人数：%.0f 人\n\n', V1(end));
%% ======================== 4. 无干预仿真（对照） ========================
control_enabled = false;
clear sigmaX_ode;  % 清空持久化变量
[t2, y2] = ode45(@(t,y) sigmaX_ode(t,y,N,beta_E,beta_I,sigma1,sigma2,gamma,omega,eta,v_rate,tau_vax,control_enabled), tspan, y0);
I2 = y2(:,4);
[peak_I2, peak_idx2] = max(I2);
peak_day2 = t2(peak_idx2);
fprintf('===== 无动态干预结果 =====\n');
fprintf('感染高峰出现在第 %.1f 天\n', peak_day2);
fprintf('峰值感染人数：%.0f 人（占总人口 %.2f%%）\n', peak_I2, peak_I2/N*100);
fprintf('无干预峰值是有干预的 %.2f 倍\n\n', peak_I2/peak_I1);
%% ======================== 5. 可视化 ========================
% 图1：有干预的全人群曲线
figure('Color','w','Position',[100,100,900,550]);
plot(t1, S1/1e6, 'b-', 'LineWidth',1.5, 'DisplayName','易感(S)');
hold on;
plot(t1, E_total1/1e6, 'Color',[0.85,0.33,0.10], 'LineWidth',1.5, 'DisplayName','潜伏(E)');
plot(t1, I1/1e6, 'r-', 'LineWidth',1.5, 'DisplayName','感染(I)');
plot(t1, R1/1e6, 'm-', 'LineWidth',1.5, 'DisplayName','康复(R)');
plot(t1, V1/1e6, 'g-', 'LineWidth',1.5, 'DisplayName','疫苗免疫(V)');
xlabel('时间 (天)', 'FontSize',12);
ylabel('人数 (百万)', 'FontSize',12);
title('Sigma-X病毒传播动力学仿真（有动态干预）', 'FontSize',14);
legend('Location','northeast', 'FontSize',10);
grid on;
set(gca, 'GridAlpha',0.3, 'FontName','Microsoft YaHei');
% 图2：干预效果对比
figure('Color','w','Position',[100,100,900,550]);
plot(t1, I1/1e6, 'r-', 'LineWidth',1.5, 'DisplayName','有动态干预');
hold on;
plot(t2, I2/1e6, 'r--', 'LineWidth',1.5, 'DisplayName','无动态干预');
xlabel('时间 (天)', 'FontSize',12);
ylabel('感染人数 (百万)', 'FontSize',12);
title('动态干预对感染规模的影响', 'FontSize',14);
legend('Location','northeast', 'FontSize',10);
grid on;
set(gca, 'GridAlpha',0.3, 'FontName','Microsoft YaHei');
%% ======================== ODE求解函数（局部函数） ========================
function dydt = sigmaX_ode(t, y, N, beta_E, beta_I, sigma1, sigma2, gamma, omega, eta, v_rate, tau_vax, control_enabled)
persistent control_status  % 持久化变量，保存管控状态，避免阈值振荡
%% 1. 计算管控系数c
if ~control_enabled
    c = 1.0;  % 无干预场景，接触系数恒为1
else
    % 初始化管控状态：0=未管控, 1=严格管控, 2=松动管控
    if isempty(control_status) || t == 0
        control_status = 0;
    end
    P = y(4) / N;  % 活跃感染者占比
    % 更新管控状态（迟滞逻辑）
    switch control_status
        case 0  % 未管控状态
            if P > 0.01  % 超过1%触发严格管控
                control_status = 1;
            end
        case 1  % 严格管控状态
            if P < 0.001  % 低于0.1%触发松动
                control_status = 2;
            end
        case 2  % 松动管控状态
            if P > 0.01  % 再次超过1%回到严格管控
                control_status = 1;
            end
    end
    % 赋值管控系数
    switch control_status
        case 0, c = 1.0;
        case 1, c = 0.25;  % 接触人数降75%
        case 2, c = 0.5;   % 接触人数恢复至50%
    end
end
%% 2. 计算感染力和接种量
lambda = c * (beta_E * y(3) + beta_I * y(4)) / N;  % 单位易感者感染率
if t >= tau_vax
    v = min(v_rate, y(1));  % 接种人数不超过剩余易感人群
else
    v = 0;
end
%% 3. 计算各状态导数
dydt = zeros(20, 1);
sum_U = sum(y(7:20));  % 所有接种未免疫人群总和
% S: 未接种易感者
dydt(1) = omega * y(5) + omega * y(6) + (1 - eta) * y(20) - lambda * y(1) - v;
% E1: 潜伏前期（无传染性）
dydt(2) = lambda * (y(1) + sum_U) - sigma1 * y(2);
% E2: 潜伏后期（有传染性）
dydt(3) = sigma1 * y(2) - sigma2 * y(3);
% I: 正式感染期
dydt(4) = sigma2 * y(3) - gamma * y(4);
% R: 康复免疫
dydt(5) = gamma * y(4) - omega * y(5);
% V: 疫苗免疫
dydt(6) = eta * y(20) - omega * y(6);
% U1: 接种后第1天
dydt(7) = v - y(7) - lambda * y(7);
% U2~U13: 接种后第2~13天
for i = 8:19
    dydt(i) = y(i-1) - y(i) - lambda * y(i);
end
% U14: 接种后第14天
dydt(20) = y(19) - y(20) - lambda * y(20);
end