package com.ventrya.api.unit;

import com.ventrya.api.dto.request.LoginRequestDTO;
import com.ventrya.api.dto.request.RegisterRequestDTO;
import com.ventrya.api.dto.response.AuthResponse;
import com.ventrya.api.entity.User;
import com.ventrya.api.entity.enums.ProfessionalArea;
import com.ventrya.api.entity.enums.Role;
import com.ventrya.api.mapper.UserMapper;
import com.ventrya.api.repository.UserRepository;
import com.ventrya.api.security.JwtService;
import com.ventrya.api.service.AuthService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.http.HttpStatus;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.authentication.BadCredentialsException;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.web.server.ResponseStatusException;

import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

class AuthServiceTest {

    private UserRepository userRepository;
    private PasswordEncoder passwordEncoder;
    private AuthenticationManager authenticationManager;
    private JwtService jwtService;
    private AuthService authService;

    @BeforeEach
    void setUp() {
        userRepository = mock(UserRepository.class);
        passwordEncoder = mock(PasswordEncoder.class);
        authenticationManager = mock(AuthenticationManager.class);
        jwtService = mock(JwtService.class);
        authService = new AuthService(userRepository, passwordEncoder,
                authenticationManager, jwtService, new UserMapper());
    }

    @Test
    @DisplayName("Cadastro: cria usuário STUDENT com e-mail normalizado e senha criptografada")
    void registerCreatesStudent() {
        when(userRepository.existsByEmail("maria@teste.com")).thenReturn(false);
        when(passwordEncoder.encode("senha12345")).thenReturn("HASH");
        when(userRepository.saveAndFlush(any(User.class))).thenAnswer(inv -> {
            User u = inv.getArgument(0);
            u.setId(1L);
            return u;
        });
        when(jwtService.generateToken(any(User.class))).thenReturn("jwt-token");

        AuthResponse response = authService.register(new RegisterRequestDTO(
                "  Maria Silva ", "  Maria@Teste.com ", "senha12345", ProfessionalArea.TECHNOLOGY));

        ArgumentCaptor<User> captor = ArgumentCaptor.forClass(User.class);
        verify(userRepository).saveAndFlush(captor.capture());
        User saved = captor.getValue();

        assertThat(saved.getName()).isEqualTo("Maria Silva");
        assertThat(saved.getEmail()).isEqualTo("maria@teste.com");
        assertThat(saved.getPassword()).isEqualTo("HASH");
        assertThat(saved.getRole()).isEqualTo(Role.STUDENT);
        assertThat(saved.getCreatedAt()).isNotNull();
        assertThat(response.token()).isEqualTo("jwt-token");
    }

    @Test
    @DisplayName("Cadastro: e-mail já existente retorna 409 CONFLICT")
    void registerDuplicateEmail() {
        when(userRepository.existsByEmail("maria@teste.com")).thenReturn(true);

        assertThatThrownBy(() -> authService.register(new RegisterRequestDTO(
                "Maria", "maria@teste.com", "senha12345", ProfessionalArea.OTHER)))
                .isInstanceOf(ResponseStatusException.class)
                .satisfies(e -> assertThat(((ResponseStatusException) e).getStatusCode())
                        .isEqualTo(HttpStatus.CONFLICT));

        verify(userRepository, never()).saveAndFlush(any());
    }

    @Test
    @DisplayName("Login: credenciais inválidas retornam 401 UNAUTHORIZED")
    void loginInvalidCredentials() {
        when(authenticationManager.authenticate(any()))
                .thenThrow(new BadCredentialsException("bad"));

        assertThatThrownBy(() -> authService.login(new LoginRequestDTO("x@teste.com", "errada")))
                .isInstanceOf(ResponseStatusException.class)
                .satisfies(e -> assertThat(((ResponseStatusException) e).getStatusCode())
                        .isEqualTo(HttpStatus.UNAUTHORIZED));
    }

    @Test
    @DisplayName("Login: credenciais válidas retornam token JWT")
    void loginValid() {
        User user = new User();
        user.setId(5L);
        user.setEmail("ana@teste.com");
        user.setRole(Role.STUDENT);
        when(userRepository.findByEmail("ana@teste.com")).thenReturn(Optional.of(user));
        when(jwtService.generateToken(user)).thenReturn("jwt-ok");

        AuthResponse response = authService.login(new LoginRequestDTO(" ANA@teste.com ", "senha12345"));

        assertThat(response.token()).isEqualTo("jwt-ok");
        assertThat(response.user().email()).isEqualTo("ana@teste.com");
    }
}
