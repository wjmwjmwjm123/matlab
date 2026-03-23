%% =========================================================
%  Sigma-X 传播模型（SEIRV + 时滞 + 迟滞控制）
%% =========================================================

clear; clc; close all;

%% ===================== 参数定义 =====================
params.N = 1e7;

% 传播参数
params.beta_I = 0.45;
params.beta_E = 0.225;

% 状态转移
params.sigma1 = 1/4;   
params.sigma2 = 1/2;   
params.gamma  = 1/8;   
params.delta  = 1/14;  
params.omega  = 0.1/150; 

% 疫苗
params.vacc_rate = 1e5;

% 干预阈值
params.th_high = 0.01;   
params.th_low  = 0.001;  

%% ===================== 初始条件 =====================
S0  = params.N - 100;
E10 = 0;
E20 = 0;
I0  = 100;
R0  = 0;
Vw0 = 0;
V0  = 0;

y0 = [S0; E10; E20; I0; R0; Vw0; V0];

%% ===================== 时间设置 =====================
tspan = 0:0.1:200;

%% ===================== ODE 设置 =====================
options = odeset(...
    'RelTol',1e-6,...
    'AbsTol',1e-8,...
    'NonNegative',1:7);

%% ===================== 求解 =====================
[t, y] = ode45(@(t,y) SigmaX_ODE(t,y,params), tspan, y0, options);

%% ===================== 数据提取 =====================
S  = y(:,1);
E1 = y(:,2);
E2 = y(:,3);
I  = y(:,4);
R  = y(:,5);
Vw = y(:,6);
V  = y(:,7);

E_total = E1 + E2;

%% ===================== 可视化 =====================
figure('Color','w','Position',[100 100 1000 600]);

plot(t,S,'b','LineWidth',2); hold on;
plot(t,E_total,'m','LineWidth',2);
plot(t,I,'r','LineWidth',2.5);
plot(t,R,'g','LineWidth',2);
plot(t,V,'k','LineWidth',2);

legend({'易感人群 S',...
        '潜伏人群 E',...
        '感染人群 I',...
        '康复人群 R',...
        '免疫人群 V'},...
        'Location','best');

xlabel('时间（天）','FontSize',12);
ylabel('人数','FontSize',12);
title('Sigma-X 传播动力学（含迟滞干预机制）','FontSize',14);

grid on;
box on;

%% ===================== 峰值输出 =====================
[I_peak, idx] = max(I);
t_peak = t(idx);

fprintf('感染峰值人数：%.0f 人\n', I_peak);
fprintf('峰值出现时间：%.2f 天\n', t_peak);

%% =========================================================
%% 局部函数：ODE系统（含迟滞控制）
%% =========================================================
function dydt = SigmaX_ODE(t, y, p)

% -------- 状态变量 --------
S  = y(1);
E1 = y(2);
E2 = y(3);
I  = y(4);
R  = y(5);
Vw = y(6);
V  = y(7);

% -------- 迟滞控制状态 --------
persistent control_state

if isempty(control_state)
    control_state = 0; % 0=正常，1=强干预，2=放松
end

% -------- 当前感染比例 --------
P = I / p.N;

% -------- 迟滞逻辑 --------
if control_state == 0 && P > p.th_high
    control_state = 1;
elseif control_state == 1 && P < p.th_low
    control_state = 2;
end

% -------- 接触强度 --------
switch control_state
    case 0
        c = 1.0;
    case 1
        c = 0.25;
    case 2
        c = 0.5;
end

% -------- 感染力 --------
lambda = c * (p.beta_I * I + p.beta_E * E2) / p.N;

% -------- 疫苗 --------
if t >= 30
    u = p.vacc_rate;
else
    u = 0;
end

% -------- 微分方程 --------
dS  = -lambda*S - u + p.omega*R + p.omega*V;
dE1 = lambda*S - p.sigma1*E1;
dE2 = p.sigma1*E1 - p.sigma2*E2;
dI  = p.sigma2*E2 - p.gamma*I;
dR  = p.gamma*I - p.omega*R;
dVw = u - p.delta*Vw;
dV  = 0.85*p.delta*Vw - p.omega*V;

dydt = [dS; dE1; dE2; dI; dR; dVw; dV];

end