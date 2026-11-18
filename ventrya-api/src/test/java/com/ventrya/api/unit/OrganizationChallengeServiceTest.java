package com.ventrya.api.unit;

import com.ventrya.api.dto.request.ChallengeRequestDTO;
import com.ventrya.api.dto.request.OrganizationRequestDTO;
import com.ventrya.api.dto.response.ChallengeResponseDTO;
import com.ventrya.api.dto.response.OrganizationResponseDTO;
import com.ventrya.api.entity.Challenge;
import com.ventrya.api.entity.Organization;
import com.ventrya.api.entity.enums.ChallengeStatus;
import com.ventrya.api.entity.enums.Difficulty;
import com.ventrya.api.entity.enums.ProfessionalArea;
import com.ventrya.api.mapper.ChallengeMapper;
import com.ventrya.api.mapper.OrganizationMapper;
import com.ventrya.api.repository.ChallengeRepository;
import com.ventrya.api.repository.OrganizationRepository;
import com.ventrya.api.service.ChallengeService;
import com.ventrya.api.service.OrganizationService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.data.domain.PageImpl;
import org.springframework.data.domain.PageRequest;
import org.springframework.http.HttpStatus;
import org.springframework.web.server.ResponseStatusException;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.Date;
import java.util.List;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

class OrganizationChallengeServiceTest {

    private OrganizationRepository organizationRepository;
    private ChallengeRepository challengeRepository;
    private OrganizationService organizationService;
    private ChallengeService challengeService;

    @BeforeEach
    void setUp() {
        organizationRepository = mock(OrganizationRepository.class);
        challengeRepository = mock(ChallengeRepository.class);
        organizationService = new OrganizationService(organizationRepository, new OrganizationMapper());
        challengeService = new ChallengeService(challengeRepository, new ChallengeMapper(), organizationRepository);
        when(organizationRepository.save(any(Organization.class))).thenAnswer(inv -> inv.getArgument(0));
        when(challengeRepository.save(any(Challenge.class))).thenAnswer(inv -> inv.getArgument(0));
    }

    private Organization ong() {
        Organization o = new Organization();
        o.setId(10L);
        o.setName("ONG Parceira");
        o.setEmail("contato@ong.org");
        o.setDescription("ONG de teste");
        o.setCreatedAt(LocalDateTime.now());
        return o;
    }

    private Challenge desafio(Organization org) {
        Challenge c = new Challenge();
        c.setId(1L);
        c.setTitle("Planilha de inscrições");
        c.setDescription("Criar planilha para organizar inscrições do evento");
        c.setProfessionalArea(ProfessionalArea.ADMINISTRATION);
        c.setDifficulty(Difficulty.BEGINNER);
        c.setStatus(ChallengeStatus.OPEN);
        c.setDeadLine(new Date());
        c.setCreatedAt(LocalDateTime.now());
        c.setOrganization(org);
        return c;
    }

    private OrganizationRequestDTO orgRequest(String email) {
        return new OrganizationRequestDTO("ONG Futuro Jovem", email,
                "Apoia jovens no primeiro emprego", "https://futurojovem.org");
    }

    private ChallengeRequestDTO challengeRequest() {
        return new ChallengeRequestDTO("Planilha do evento",
                "Criar uma planilha para organizar as inscrições do evento comunitário.",
                ProfessionalArea.ADMINISTRATION, Difficulty.BEGINNER, "Excel",
                LocalDate.now().plusDays(30));
    }

    // ---------------- Organização ----------------

    @Test
    @DisplayName("Organização: busca por id existente retorna DTO")
    void organizationFound() {
        when(organizationRepository.findById(10L)).thenReturn(Optional.of(ong()));

        OrganizationResponseDTO dto = organizationService.findById(10L);

        assertThat(dto.id()).isEqualTo(10L);
        assertThat(dto.name()).isEqualTo("ONG Parceira");
    }

    @Test
    @DisplayName("Organização: id inexistente retorna 404")
    void organizationNotFound() {
        when(organizationRepository.findById(99L)).thenReturn(Optional.empty());

        assertThatThrownBy(() -> organizationService.findById(99L))
                .isInstanceOf(ResponseStatusException.class)
                .satisfies(e -> assertThat(((ResponseStatusException) e).getStatusCode())
                        .isEqualTo(HttpStatus.NOT_FOUND));
    }

    @Test
    @DisplayName("Organização: create salva e preenche data de criação")
    void organizationCreate() {
        when(organizationRepository.existsByEmail("nova@ong.org")).thenReturn(false);

        OrganizationResponseDTO dto = organizationService.create(orgRequest("nova@ong.org"));

        assertThat(dto.email()).isEqualTo("nova@ong.org");
        assertThat(dto.createdAt()).isNotNull();
        verify(organizationRepository).save(any(Organization.class));
    }

    @Test
    @DisplayName("Organização: create com e-mail duplicado retorna 409")
    void organizationCreateDuplicate() {
        when(organizationRepository.existsByEmail("contato@ong.org")).thenReturn(true);

        assertThatThrownBy(() -> organizationService.create(orgRequest("contato@ong.org")))
                .isInstanceOf(ResponseStatusException.class)
                .satisfies(e -> assertThat(((ResponseStatusException) e).getStatusCode())
                        .isEqualTo(HttpStatus.CONFLICT));
        verify(organizationRepository, never()).save(any());
    }

    @Test
    @DisplayName("Organização: update altera os dados")
    void organizationUpdate() {
        when(organizationRepository.findById(10L)).thenReturn(Optional.of(ong()));

        OrganizationResponseDTO dto = organizationService.update(10L, orgRequest("contato@ong.org"));

        assertThat(dto.name()).isEqualTo("ONG Futuro Jovem");
    }

    @Test
    @DisplayName("Organização: delete com desafios vinculados retorna 409")
    void organizationDeleteWithChallenges() {
        Organization org = ong();
        org.getChallenges().add(desafio(org));
        when(organizationRepository.findById(10L)).thenReturn(Optional.of(org));

        assertThatThrownBy(() -> organizationService.delete(10L))
                .isInstanceOf(ResponseStatusException.class)
                .satisfies(e -> assertThat(((ResponseStatusException) e).getStatusCode())
                        .isEqualTo(HttpStatus.CONFLICT));
        verify(organizationRepository, never()).delete(any());
    }

    @Test
    @DisplayName("Organização: delete sem desafios remove o registro")
    void organizationDelete() {
        Organization org = ong();
        when(organizationRepository.findById(10L)).thenReturn(Optional.of(org));

        organizationService.delete(10L);

        verify(organizationRepository).delete(org);
    }

    // ---------------- Desafio ----------------

    @Test
    @DisplayName("Desafio: busca por id traz dados da organização")
    void challengeFound() {
        when(challengeRepository.findById(1L)).thenReturn(Optional.of(desafio(ong())));

        ChallengeResponseDTO dto = challengeService.findById(1L);

        assertThat(dto.title()).isEqualTo("Planilha de inscrições");
        assertThat(dto.organizationId()).isEqualTo(10L);
        assertThat(dto.organizationName()).isEqualTo("ONG Parceira");
    }

    @Test
    @DisplayName("Desafio: id inexistente retorna 404")
    void challengeNotFound() {
        when(challengeRepository.findById(2L)).thenReturn(Optional.empty());

        assertThatThrownBy(() -> challengeService.findById(2L))
                .isInstanceOf(ResponseStatusException.class);
    }

    @Test
    @DisplayName("Desafio: listagem paginada converte todos os itens")
    void challengeFindAll() {
        var page = PageRequest.of(0, 10);
        when(challengeRepository.findAll(page))
                .thenReturn(new PageImpl<>(List.of(desafio(ong()), desafio(null)), page, 2));

        var result = challengeService.findAll(page);

        assertThat(result.getTotalElements()).isEqualTo(2);
        assertThat(result.getContent().get(1).organizationId()).isNull();
    }

    @Test
    @DisplayName("Desafio: create vincula à organização e inicia com status OPEN")
    void challengeCreate() {
        when(organizationRepository.findById(10L)).thenReturn(Optional.of(ong()));

        ChallengeResponseDTO dto = challengeService.create(10L, challengeRequest());

        assertThat(dto.status()).isEqualTo(ChallengeStatus.OPEN);
        assertThat(dto.organizationId()).isEqualTo(10L);
    }

    @Test
    @DisplayName("Desafio: create em organização inexistente retorna 404")
    void challengeCreateOrgNotFound() {
        when(organizationRepository.findById(77L)).thenReturn(Optional.empty());

        assertThatThrownBy(() -> challengeService.create(77L, challengeRequest()))
                .isInstanceOf(ResponseStatusException.class)
                .satisfies(e -> assertThat(((ResponseStatusException) e).getStatusCode())
                        .isEqualTo(HttpStatus.NOT_FOUND));
    }

    @Test
    @DisplayName("Desafio: delete sem candidaturas remove o registro")
    void challengeDelete() {
        Challenge c = desafio(ong());
        when(challengeRepository.findById(1L)).thenReturn(Optional.of(c));

        challengeService.delete(1L);

        verify(challengeRepository).delete(c);
    }
}
