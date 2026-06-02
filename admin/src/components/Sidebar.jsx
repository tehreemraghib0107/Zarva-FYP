import React from 'react';
import { NavLink, useNavigate } from 'react-router-dom';
import { 
    LayoutDashboard, 
    Gem, 
    Users, 
    ShoppingCart, 
    BarChart3, 
    Megaphone, 
    MessageSquare, 
    LogOut,
    Settings,
    Archive
} from 'lucide-react';

const Sidebar = () => {
    const navigate = useNavigate();

    const handleLogout = () => {
        localStorage.removeItem('adminToken');
        navigate('/login');
    };

    const navItems = [
        { icon: <LayoutDashboard size={20} />, label: 'Dashboard', path: '/dashboard' },
        { icon: <Archive size={20} />, label: 'Inventory', path: '/dashboard/inventory' },
        { icon: <Gem size={20} />, label: 'Products', path: '/dashboard/products' },
        { icon: <Users size={20} />, label: 'Users', path: '/dashboard/users' },
        { icon: <ShoppingCart size={20} />, label: 'Orders', path: '/dashboard/orders' },
        { icon: <BarChart3 size={20} />, label: 'Analytics', path: '/dashboard/analytics' },
        { icon: <Megaphone size={20} />, label: 'Promotions', path: '/dashboard/promotions' },
        { icon: <MessageSquare size={20} />, label: 'Reviews', path: '/dashboard/reviews' },
    ];

    return (
        <div style={{
            width: '260px',
            height: '100vh',
            backgroundColor: 'var(--primary-bg)',
            color: 'white',
            display: 'flex',
            flexDirection: 'column',
            position: 'fixed',
            left: 0,
            top: 0,
            zIndex: 1000,
            overflowY: 'auto'
        }}>
            <div style={{ padding: '30px 20px', textAlign: 'center' }}>
                <h2 style={{ fontSize: '24px', fontWeight: 'bold', letterSpacing: '1px' }}>ZARVA</h2>
                <p style={{ fontSize: '10px', opacity: 0.6, marginTop: '5px' }}>ADMIN PANEL</p>
            </div>

            <nav style={{ flex: 1, padding: '20px' }}>
                {navItems.map((item) => (
                    <NavLink
                        key={item.path}
                        to={item.path}
                        end={item.path === '/dashboard'}
                        style={({ isActive }) => ({
                            display: 'flex',
                            alignItems: 'center',
                            padding: '12px 15px',
                            marginBottom: '8px',
                            borderRadius: '10px',
                            color: 'white',
                            textDecoration: 'none',
                            transition: 'all 0.3s',
                            backgroundColor: isActive ? 'rgba(255,255,255,0.1)' : 'transparent',
                            borderLeft: isActive ? '4px solid white' : '4px solid transparent'
                        })}
                    >
                        <span style={{ marginRight: '12px' }}>{item.icon}</span>
                        <span style={{ fontSize: '15px' }}>{item.label}</span>
                    </NavLink>
                ))}
            </nav>

            <div style={{ padding: '20px', borderTop: '1px solid rgba(255,255,255,0.1)' }}>
                <div style={{ 
                    display: 'flex', 
                    alignItems: 'center', 
                    padding: '12px 15px', 
                    cursor: 'pointer',
                    color: '#ff4d4d'
                }} onClick={handleLogout}>
                    <LogOut size={20} style={{ marginRight: '12px' }} />
                    <span style={{ fontSize: '15px', fontWeight: 'bold' }}>Logout</span>
                </div>
            </div>
        </div>
    );
};

export default Sidebar;
